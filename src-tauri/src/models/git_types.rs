use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitBranch { pub name: String, pub is_current: bool, pub is_remote: bool, pub last_commit_sha: String }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitCommit { pub sha: String, pub message: String, pub author: String, pub email: String, pub timestamp: i64 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitStatus { pub staged: Vec<String>, pub modified: Vec<String>, pub untracked: Vec<String> }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AISuggestion { pub resolved_text: String, pub strategy: String, pub reasoning: String, pub confidence: f64 }
