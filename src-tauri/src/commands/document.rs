use crate::models::Document;
use crate::AppState;
use chrono::Utc;
use uuid::Uuid;
use std::path::{Path, PathBuf};

fn validate_path(project_root: &str, target: &str) -> Result<PathBuf, String> {
    let root = Path::new(project_root).canonicalize().map_err(|e| e.to_string())?;
    let candidate = Path::new(target);
    let abs = if candidate.is_absolute() {
        candidate.to_path_buf()
    } else {
        root.join(candidate)
    };
    let parent = abs.parent().ok_or_else(|| "no parent".to_string())?;
    std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let canon_parent = parent.canonicalize().map_err(|e| e.to_string())?;
    if !canon_parent.starts_with(&root) {
        return Err("path escapes project root".into());
    }
    if abs.exists() {
        let meta = std::fs::symlink_metadata(&abs).map_err(|e| e.to_string())?;
        if meta.file_type().is_symlink() {
            return Err("symlinks not permitted".into());
        }
    }
    Ok(canon_parent.join(abs.file_name().ok_or_else(|| "no filename".to_string())?))
}

#[tauri::command]
pub async fn document_read(project_root: String, path: String) -> Result<String, String> {
    let p = validate_path(&project_root, &path)?;
    tokio::fs::read_to_string(&p).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn document_write(project_root: String, path: String, content: String) -> Result<(), String> {
    let p = validate_path(&project_root, &path)?;
    tokio::fs::write(&p, content).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn document_create(
    project_id: String,
    project_root: String,
    filename: String,
    state: tauri::State<'_, AppState>,
) -> Result<Document, String> {
    let p = validate_path(&project_root, &filename)?;
    tokio::fs::write(&p, "").await.map_err(|e| e.to_string())?;
    let doc = Document {
        id: Uuid::new_v4().to_string(),
        project_id,
        filename: filename.clone(),
        relative_path: filename,
        word_count: 0,
        last_modified: Utc::now().timestamp(),
    };
    let db = state.lock().map_err(|e| e.to_string())?;
    db.insert_document(&doc).map_err(|e| e.to_string())?;
    Ok(doc)
}

#[tauri::command]
pub fn document_delete(id: String, state: tauri::State<'_, AppState>) -> Result<(), String> {
    let db = state.lock().map_err(|e| e.to_string())?;
    db.delete_document(&id).map_err(|e| e.to_string())
}
