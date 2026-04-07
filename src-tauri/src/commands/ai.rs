use crate::models::AISuggestion;
use crate::storage::credentials;
use serde_json::json;

#[tauri::command]
pub fn ai_save_key(key: String) -> Result<(), String> {
    credentials::save_ai_key(&key).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn ai_has_key() -> Result<bool, String> {
    Ok(credentials::load_ai_key().map_err(|e| e.to_string())?.is_some())
}

#[tauri::command]
pub async fn ai_resolve_conflict(ours: String, theirs: String, base: Option<String>) -> Result<AISuggestion, String> {
    let key = credentials::load_ai_key().map_err(|e| e.to_string())?
        .ok_or_else(|| "no API key".to_string())?;
    let prompt = format!(
        "You are resolving a Git merge conflict in an academic document. Provide the merged text.\n\nBASE:\n{}\n\nOURS:\n{}\n\nTHEIRS:\n{}\n\nReturn JSON with fields: resolved_text, strategy, reasoning, confidence (0-1).",
        base.unwrap_or_default(), ours, theirs
    );
    let body = json!({
        "model": "claude-opus-4-5",
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": prompt}],
    });
    let client = reqwest::Client::new();
    let resp = client.post("https://api.anthropic.com/v1/messages")
        .header("x-api-key", key)
        .header("anthropic-version", "2023-06-01")
        .header("content-type", "application/json")
        .json(&body)
        .send().await.map_err(|e| e.to_string())?;
    let v: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
    let text = v["content"][0]["text"].as_str().unwrap_or("").to_string();
    if let Ok(parsed) = serde_json::from_str::<AISuggestion>(&text) {
        Ok(parsed)
    } else {
        Ok(AISuggestion {
            resolved_text: text,
            strategy: "ai".into(),
            reasoning: "Model returned non-JSON output".into(),
            confidence: 0.5,
        })
    }
}
