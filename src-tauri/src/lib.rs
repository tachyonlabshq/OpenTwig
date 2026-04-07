pub mod models;
pub mod storage;
pub mod commands;

use std::sync::Mutex;
use tauri::Manager;

pub type AppState = Mutex<storage::Database>;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let data_dir = app.path().app_data_dir().expect("app data dir");
            std::fs::create_dir_all(&data_dir).ok();
            let db_path = data_dir.join("opentwig.db");
            let db = storage::Database::new(&db_path).expect("init db");
            app.manage(Mutex::new(db) as AppState);
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::git::git_status,
            commands::git::git_clone,
            commands::git::git_commit,
            commands::git::git_branches,
            commands::git::git_push,
            commands::git::git_pull,
            commands::git::git_create_branch,
            commands::git::git_checkout,
            commands::git::git_log,
            commands::project::project_create,
            commands::project::project_list,
            commands::project::project_get,
            commands::project::project_open,
            commands::project::project_delete,
            commands::project::project_documents,
            commands::git_server::git_server_add,
            commands::git_server::git_server_list,
            commands::git_server::git_server_delete,
            commands::git_server::git_server_test,
            commands::git_server::git_server_presets,
            commands::ai::ai_save_key,
            commands::ai::ai_has_key,
            commands::ai::ai_resolve_conflict,
            commands::document::document_read,
            commands::document::document_write,
            commands::document::document_create,
            commands::document::document_delete,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
