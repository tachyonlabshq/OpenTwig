use anyhow::Result;
use rusqlite::{params, Connection, Row};
use std::path::Path;

use crate::models::{Project, GitServer, GitServerKind, Document};

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn new(path: &Path) -> Result<Self> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).ok();
        }
        let conn = Connection::open(path)?;
        let db = Database { conn };
        db.init()?;
        Ok(db)
    }

    fn init(&self) -> Result<()> {
        self.conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                local_path TEXT NOT NULL,
                remote_url TEXT NOT NULL,
                git_server_id TEXT NOT NULL,
                current_branch TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                last_opened_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS git_servers (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                display_name TEXT NOT NULL,
                base_url TEXT NOT NULL,
                web_url TEXT NOT NULL,
                auth_method TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                filename TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                word_count INTEGER NOT NULL DEFAULT 0,
                last_modified INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            "#,
        )?;
        Ok(())
    }

    fn row_to_project(row: &Row) -> rusqlite::Result<Project> {
        Ok(Project {
            id: row.get(0)?,
            name: row.get(1)?,
            local_path: row.get(2)?,
            remote_url: row.get(3)?,
            git_server_id: row.get(4)?,
            current_branch: row.get(5)?,
            created_at: row.get(6)?,
            last_opened_at: row.get(7)?,
        })
    }

    pub fn insert_project(&self, p: &Project) -> Result<()> {
        self.conn.execute(
            "INSERT INTO projects (id,name,local_path,remote_url,git_server_id,current_branch,created_at,last_opened_at) VALUES (?1,?2,?3,?4,?5,?6,?7,?8)",
            params![p.id, p.name, p.local_path, p.remote_url, p.git_server_id, p.current_branch, p.created_at, p.last_opened_at],
        )?;
        Ok(())
    }

    pub fn list_projects(&self) -> Result<Vec<Project>> {
        let mut stmt = self.conn.prepare("SELECT id,name,local_path,remote_url,git_server_id,current_branch,created_at,last_opened_at FROM projects ORDER BY last_opened_at DESC")?;
        let rows = stmt.query_map([], Self::row_to_project)?;
        Ok(rows.filter_map(|r| r.ok()).collect())
    }

    pub fn get_project(&self, id: &str) -> Result<Option<Project>> {
        let mut stmt = self.conn.prepare("SELECT id,name,local_path,remote_url,git_server_id,current_branch,created_at,last_opened_at FROM projects WHERE id = ?1")?;
        let mut rows = stmt.query_map(params![id], Self::row_to_project)?;
        Ok(rows.next().and_then(|r| r.ok()))
    }

    pub fn delete_project(&self, id: &str) -> Result<()> {
        self.conn.execute("DELETE FROM projects WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn update_project_last_opened(&self, id: &str, ts: i64) -> Result<()> {
        self.conn.execute("UPDATE projects SET last_opened_at = ?1 WHERE id = ?2", params![ts, id])?;
        Ok(())
    }

    fn row_to_git_server(row: &Row) -> rusqlite::Result<GitServer> {
        let kind_str: String = row.get(1)?;
        Ok(GitServer {
            id: row.get(0)?,
            kind: GitServerKind::from_str(&kind_str).unwrap_or(GitServerKind::Custom),
            display_name: row.get(2)?,
            base_url: row.get(3)?,
            web_url: row.get(4)?,
            auth_method: row.get(5)?,
            created_at: row.get(6)?,
        })
    }

    pub fn insert_git_server(&self, s: &GitServer) -> Result<()> {
        self.conn.execute(
            "INSERT INTO git_servers (id,kind,display_name,base_url,web_url,auth_method,created_at) VALUES (?1,?2,?3,?4,?5,?6,?7)",
            params![s.id, s.kind.as_str(), s.display_name, s.base_url, s.web_url, s.auth_method, s.created_at],
        )?;
        Ok(())
    }

    pub fn list_git_servers(&self) -> Result<Vec<GitServer>> {
        let mut stmt = self.conn.prepare("SELECT id,kind,display_name,base_url,web_url,auth_method,created_at FROM git_servers ORDER BY created_at ASC")?;
        let rows = stmt.query_map([], Self::row_to_git_server)?;
        Ok(rows.filter_map(|r| r.ok()).collect())
    }

    pub fn get_git_server(&self, id: &str) -> Result<Option<GitServer>> {
        let mut stmt = self.conn.prepare("SELECT id,kind,display_name,base_url,web_url,auth_method,created_at FROM git_servers WHERE id = ?1")?;
        let mut rows = stmt.query_map(params![id], Self::row_to_git_server)?;
        Ok(rows.next().and_then(|r| r.ok()))
    }

    pub fn delete_git_server(&self, id: &str) -> Result<()> {
        self.conn.execute("DELETE FROM git_servers WHERE id = ?1", params![id])?;
        Ok(())
    }

    fn row_to_document(row: &Row) -> rusqlite::Result<Document> {
        Ok(Document {
            id: row.get(0)?,
            project_id: row.get(1)?,
            filename: row.get(2)?,
            relative_path: row.get(3)?,
            word_count: row.get::<_, i64>(4)? as u32,
            last_modified: row.get(5)?,
        })
    }

    pub fn insert_document(&self, d: &Document) -> Result<()> {
        self.conn.execute(
            "INSERT INTO documents (id,project_id,filename,relative_path,word_count,last_modified) VALUES (?1,?2,?3,?4,?5,?6)",
            params![d.id, d.project_id, d.filename, d.relative_path, d.word_count as i64, d.last_modified],
        )?;
        Ok(())
    }

    pub fn list_documents(&self, project_id: &str) -> Result<Vec<Document>> {
        let mut stmt = self.conn.prepare("SELECT id,project_id,filename,relative_path,word_count,last_modified FROM documents WHERE project_id = ?1 ORDER BY filename ASC")?;
        let rows = stmt.query_map(params![project_id], Self::row_to_document)?;
        Ok(rows.filter_map(|r| r.ok()).collect())
    }

    pub fn delete_document(&self, id: &str) -> Result<()> {
        self.conn.execute("DELETE FROM documents WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn get_setting(&self, key: &str) -> Result<Option<String>> {
        let mut stmt = self.conn.prepare("SELECT value FROM settings WHERE key = ?1")?;
        let mut rows = stmt.query_map(params![key], |r| r.get::<_, String>(0))?;
        Ok(rows.next().and_then(|r| r.ok()))
    }

    pub fn set_setting(&self, key: &str, value: &str) -> Result<()> {
        self.conn.execute(
            "INSERT INTO settings (key,value) VALUES (?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            params![key, value],
        )?;
        Ok(())
    }
}
