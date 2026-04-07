use crate::models::{Project, Document};
use crate::AppState;
use chrono::Utc;
use uuid::Uuid;
use std::path::PathBuf;

#[tauri::command]
pub async fn project_create(
    name: String,
    parent_dir: String,
    remote_url: String,
    git_server_id: String,
    state: tauri::State<'_, AppState>,
) -> Result<Project, String> {
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().timestamp();
    let local_path = PathBuf::from(&parent_dir).join(&name);
    let local_path_str = local_path.to_string_lossy().to_string();

    let lp = local_path.clone();
    let name_clone = name.clone();
    tokio::task::spawn_blocking(move || -> Result<(), String> {
        std::fs::create_dir_all(&lp).map_err(|e| e.to_string())?;
        let repo = git2::Repository::init(&lp).map_err(|e| e.to_string())?;
        let readme = lp.join("README.md");
        std::fs::write(&readme, format!("# {}\n", name_clone)).map_err(|e| e.to_string())?;
        let mut index = repo.index().map_err(|e| e.to_string())?;
        index.add_path(std::path::Path::new("README.md")).map_err(|e| e.to_string())?;
        index.write().map_err(|e| e.to_string())?;
        let tree_id = index.write_tree().map_err(|e| e.to_string())?;
        let tree = repo.find_tree(tree_id).map_err(|e| e.to_string())?;
        let sig = git2::Signature::now("OpenTwig", "opentwig@local").map_err(|e| e.to_string())?;
        repo.commit(Some("HEAD"), &sig, &sig, "Initial commit", &tree, &[]).map_err(|e| e.to_string())?;
        Ok(())
    }).await.map_err(|e| e.to_string())??;

    let project = Project {
        id, name, local_path: local_path_str, remote_url, git_server_id,
        current_branch: "main".to_string(),
        created_at: now, last_opened_at: now,
    };
    let db = state.lock().map_err(|e| e.to_string())?;
    db.insert_project(&project).map_err(|e| e.to_string())?;
    Ok(project)
}

#[tauri::command]
pub fn project_list(state: tauri::State<'_, AppState>) -> Result<Vec<Project>, String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.list_projects().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn project_get(id: String, state: tauri::State<'_, AppState>) -> Result<Option<Project>, String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.get_project(&id).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn project_open(id: String, state: tauri::State<'_, AppState>) -> Result<Option<Project>, String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    let now = Utc::now().timestamp();
    db.update_project_last_opened(&id, now).map_err(|e| e.to_string())?;
    db.get_project(&id).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn project_delete(id: String, state: tauri::State<'_, AppState>) -> Result<(), String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.delete_project(&id).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn project_documents(project_id: String, state: tauri::State<'_, AppState>) -> Result<Vec<Document>, String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.list_documents(&project_id).map_err(|e| e.to_string())
}
