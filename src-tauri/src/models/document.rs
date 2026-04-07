use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Document {
    pub id: String,
    pub project_id: String,
    pub filename: String,
    pub relative_path: String,
    pub word_count: u32,
    pub last_modified: i64,
}
