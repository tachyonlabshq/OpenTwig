use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: String,
    pub name: String,
    pub local_path: String,
    pub remote_url: String,
    pub git_server_id: String,
    pub current_branch: String,
    pub created_at: i64,
    pub last_opened_at: i64,
}
