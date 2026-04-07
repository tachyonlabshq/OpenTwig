use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum GitServerKind {
    Github,
    Gitlab,
    Gitea,
    Bitbucket,
    Custom,
}

impl GitServerKind {
    pub fn as_str(&self) -> &'static str {
        match self { Self::Github => "github", Self::Gitlab => "gitlab", Self::Gitea => "gitea", Self::Bitbucket => "bitbucket", Self::Custom => "custom" }
    }
    pub fn from_str(s: &str) -> Option<Self> {
        match s { "github" => Some(Self::Github), "gitlab" => Some(Self::Gitlab), "gitea" => Some(Self::Gitea), "bitbucket" => Some(Self::Bitbucket), "custom" => Some(Self::Custom), _ => None }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitServer {
    pub id: String,
    pub kind: GitServerKind,
    pub display_name: String,
    pub base_url: String,
    pub web_url: String,
    pub auth_method: String,
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitServerPreset {
    pub kind: String,
    pub display_name: String,
    pub base_url: String,
    pub web_url: String,
}
