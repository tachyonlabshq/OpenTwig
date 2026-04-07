use crate::models::{GitServer, GitServerKind, GitServerPreset};
use crate::storage::credentials;
use crate::AppState;
use chrono::Utc;
use uuid::Uuid;

#[tauri::command]
pub fn git_server_presets() -> Vec<GitServerPreset> {
    vec![
        GitServerPreset { kind: "github".into(), display_name: "GitHub".into(), base_url: "https://api.github.com".into(), web_url: "https://github.com".into() },
        GitServerPreset { kind: "gitlab".into(), display_name: "GitLab.com".into(), base_url: "https://gitlab.com/api/v4".into(), web_url: "https://gitlab.com".into() },
        GitServerPreset { kind: "gitea".into(), display_name: "Codeberg".into(), base_url: "https://codeberg.org/api/v1".into(), web_url: "https://codeberg.org".into() },
        GitServerPreset { kind: "bitbucket".into(), display_name: "Bitbucket".into(), base_url: "https://api.bitbucket.org/2.0".into(), web_url: "https://bitbucket.org".into() },
    ]
}

#[tauri::command]
pub fn git_server_add(
    kind: String,
    display_name: String,
    base_url: String,
    web_url: String,
    auth_method: String,
    token: Option<String>,
    state: tauri::State<'_, AppState>,
) -> Result<GitServer, String> {
    url::Url::parse(&base_url).map_err(|e| format!("invalid base_url: {}", e))?;
    url::Url::parse(&web_url).map_err(|e| format!("invalid web_url: {}", e))?;
    let kind_enum = GitServerKind::from_str(&kind).ok_or_else(|| "invalid kind".to_string())?;
    let id = Uuid::new_v4().to_string();
    let server = GitServer {
        id: id.clone(),
        kind: kind_enum,
        display_name,
        base_url,
        web_url,
        auth_method,
        created_at: Utc::now().timestamp(),
    };
    if let Some(t) = token {
        if !t.is_empty() {
            credentials::save_token(&id, &t).map_err(|e| e.to_string())?;
        }
    }
    let db = state.lock().map_err(|e| e.to_string())?;
    db.insert_git_server(&server).map_err(|e| e.to_string())?;
    Ok(server)
}

#[tauri::command]
pub fn git_server_list(state: tauri::State<'_, AppState>) -> Result<Vec<GitServer>, String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.list_git_servers().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn git_server_delete(id: String, state: tauri::State<'_, AppState>) -> Result<(), String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.delete_git_server(&id).map_err(|e| e.to_string())?;
    let _ = credentials::delete_token(&id);
    Ok(())
}

#[tauri::command]
pub async fn git_server_test(id: String, state: tauri::State<'_, AppState>) -> Result<bool, String> {
    let (server, token) = {
        let db = state.lock().map_err(|e| e.to_string())?;
        let s = db.get_git_server(&id).map_err(|e| e.to_string())?.ok_or_else(|| "not found".to_string())?;
        let t = credentials::load_token(&id).map_err(|e| e.to_string())?;
        (s, t)
    };
    let endpoint = match server.kind {
        GitServerKind::Github => format!("{}/user", server.base_url),
        GitServerKind::Gitlab => format!("{}/user", server.base_url),
        GitServerKind::Gitea => format!("{}/user", server.base_url),
        GitServerKind::Bitbucket => format!("{}/user", server.base_url),
        GitServerKind::Custom => server.base_url.clone(),
    };
    let client = reqwest::Client::builder()
        .user_agent("OpenTwig")
        .build()
        .map_err(|e| e.to_string())?;
    let mut req = client.get(&endpoint);
    if let Some(t) = token {
        req = match server.kind {
            GitServerKind::Github => req.header("Authorization", format!("Bearer {}", t)).header("Accept", "application/vnd.github+json"),
            _ => req.header("Authorization", format!("Bearer {}", t)),
        };
    }
    let resp = req.send().await.map_err(|e| e.to_string())?;
    Ok(resp.status().is_success())
}
