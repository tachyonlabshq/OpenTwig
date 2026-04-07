use crate::models::*;
use crate::storage::credentials;
use git2::{Repository, RemoteCallbacks, Cred, FetchOptions, PushOptions};

#[tauri::command]
pub async fn git_status(path: String) -> Result<GitStatus, String> {
    tokio::task::spawn_blocking(move || -> Result<GitStatus, String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let mut staged = vec![];
        let mut modified = vec![];
        let mut untracked = vec![];
        let statuses = repo.statuses(None).map_err(|e| e.to_string())?;
        for entry in statuses.iter() {
            let p = entry.path().unwrap_or("").to_string();
            let s = entry.status();
            if s.is_index_new() || s.is_index_modified() { staged.push(p.clone()); }
            if s.is_wt_modified() || s.is_wt_deleted() { modified.push(p.clone()); }
            if s.is_wt_new() { untracked.push(p); }
        }
        Ok(GitStatus { staged, modified, untracked })
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_clone(url: String, path: String, server_id: String) -> Result<(), String> {
    let token = credentials::load_token(&server_id).map_err(|e| e.to_string())?;
    tokio::task::spawn_blocking(move || -> Result<(), String> {
        let mut callbacks = RemoteCallbacks::new();
        if let Some(t) = token {
            callbacks.credentials(move |_url, _user, _allowed| Cred::userpass_plaintext("oauth2", &t));
        } else {
            callbacks.credentials(|_url, username, _allowed| Cred::ssh_key_from_agent(username.unwrap_or("git")));
        }
        let mut fo = FetchOptions::new();
        fo.remote_callbacks(callbacks);
        let mut builder = git2::build::RepoBuilder::new();
        builder.fetch_options(fo);
        builder.clone(&url, std::path::Path::new(&path)).map_err(|e| e.to_string())?;
        Ok(())
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_commit(path: String, message: String, author: String, email: String) -> Result<String, String> {
    tokio::task::spawn_blocking(move || -> Result<String, String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let mut index = repo.index().map_err(|e| e.to_string())?;
        index.add_all(["*"].iter(), git2::IndexAddOption::DEFAULT, None).map_err(|e| e.to_string())?;
        index.write().map_err(|e| e.to_string())?;
        let tree_id = index.write_tree().map_err(|e| e.to_string())?;
        let tree = repo.find_tree(tree_id).map_err(|e| e.to_string())?;
        let sig = git2::Signature::now(&author, &email).map_err(|e| e.to_string())?;
        let parent_commit = repo.head().ok().and_then(|h| h.peel_to_commit().ok());
        let parents: Vec<&git2::Commit> = parent_commit.iter().collect();
        let oid = repo.commit(Some("HEAD"), &sig, &sig, &message, &tree, &parents).map_err(|e| e.to_string())?;
        Ok(oid.to_string())
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_branches(path: String) -> Result<Vec<GitBranch>, String> {
    tokio::task::spawn_blocking(move || -> Result<Vec<GitBranch>, String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let mut branches = vec![];
        let head = repo.head().ok();
        let head_name = head.as_ref().and_then(|h| h.shorthand().map(|s| s.to_string()));
        for branch in repo.branches(None).map_err(|e| e.to_string())? {
            let (b, btype) = branch.map_err(|e| e.to_string())?;
            let name = b.name().map_err(|e| e.to_string())?.unwrap_or("").to_string();
            let is_current = head_name.as_deref() == Some(&name) && btype == git2::BranchType::Local;
            let sha = b.get().target().map(|o| o.to_string()).unwrap_or_default();
            branches.push(GitBranch { name, is_current, is_remote: btype == git2::BranchType::Remote, last_commit_sha: sha });
        }
        Ok(branches)
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_push(path: String, remote: String, branch: String, server_id: String) -> Result<(), String> {
    let token = credentials::load_token(&server_id).map_err(|e| e.to_string())?;
    tokio::task::spawn_blocking(move || -> Result<(), String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let mut remote_obj = repo.find_remote(&remote).map_err(|e| e.to_string())?;
        let mut callbacks = RemoteCallbacks::new();
        if let Some(t) = token {
            callbacks.credentials(move |_url, _user, _allowed| Cred::userpass_plaintext("oauth2", &t));
        }
        let mut po = PushOptions::new();
        po.remote_callbacks(callbacks);
        let refspec = format!("refs/heads/{}:refs/heads/{}", branch, branch);
        remote_obj.push(&[&refspec], Some(&mut po)).map_err(|e| e.to_string())?;
        Ok(())
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_pull(path: String, remote: String, branch: String, server_id: String) -> Result<(), String> {
    let token = credentials::load_token(&server_id).map_err(|e| e.to_string())?;
    tokio::task::spawn_blocking(move || -> Result<(), String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let mut callbacks = RemoteCallbacks::new();
        if let Some(t) = token { callbacks.credentials(move |_url, _user, _allowed| Cred::userpass_plaintext("oauth2", &t)); }
        let mut fo = FetchOptions::new();
        fo.remote_callbacks(callbacks);
        let mut remote_obj = repo.find_remote(&remote).map_err(|e| e.to_string())?;
        remote_obj.fetch(&[&branch], Some(&mut fo), None).map_err(|e| e.to_string())?;
        let fetch_head = repo.find_reference("FETCH_HEAD").map_err(|e| e.to_string())?;
        let fetch_commit = repo.reference_to_annotated_commit(&fetch_head).map_err(|e| e.to_string())?;
        let analysis = repo.merge_analysis(&[&fetch_commit]).map_err(|e| e.to_string())?;
        if analysis.0.is_fast_forward() {
            let refname = format!("refs/heads/{}", branch);
            let mut reference = repo.find_reference(&refname).map_err(|e| e.to_string())?;
            reference.set_target(fetch_commit.id(), "Fast-forward").map_err(|e| e.to_string())?;
            repo.set_head(&refname).map_err(|e| e.to_string())?;
            repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force())).map_err(|e| e.to_string())?;
        }
        Ok(())
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_create_branch(path: String, name: String, from: Option<String>) -> Result<(), String> {
    tokio::task::spawn_blocking(move || -> Result<(), String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let target_commit = if let Some(from_name) = from {
            let r = repo.find_branch(&from_name, git2::BranchType::Local).map_err(|e| e.to_string())?;
            r.get().peel_to_commit().map_err(|e| e.to_string())?
        } else {
            repo.head().map_err(|e| e.to_string())?.peel_to_commit().map_err(|e| e.to_string())?
        };
        repo.branch(&name, &target_commit, false).map_err(|e| e.to_string())?;
        Ok(())
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_checkout(path: String, branch: String) -> Result<(), String> {
    tokio::task::spawn_blocking(move || -> Result<(), String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let refname = format!("refs/heads/{}", branch);
        let obj = repo.revparse_single(&refname).map_err(|e| e.to_string())?;
        repo.checkout_tree(&obj, None).map_err(|e| e.to_string())?;
        repo.set_head(&refname).map_err(|e| e.to_string())?;
        Ok(())
    }).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn git_log(path: String, limit: u32) -> Result<Vec<GitCommit>, String> {
    tokio::task::spawn_blocking(move || -> Result<Vec<GitCommit>, String> {
        let repo = Repository::open(&path).map_err(|e| e.to_string())?;
        let mut walk = repo.revwalk().map_err(|e| e.to_string())?;
        walk.push_head().map_err(|e| e.to_string())?;
        let mut commits = vec![];
        for (i, oid) in walk.enumerate() {
            if i >= limit as usize { break; }
            let oid = oid.map_err(|e| e.to_string())?;
            let commit = repo.find_commit(oid).map_err(|e| e.to_string())?;
            commits.push(GitCommit {
                sha: oid.to_string(),
                message: commit.message().unwrap_or("").to_string(),
                author: commit.author().name().unwrap_or("").to_string(),
                email: commit.author().email().unwrap_or("").to_string(),
                timestamp: commit.time().seconds(),
            });
        }
        Ok(commits)
    }).await.map_err(|e| e.to_string())?
}
