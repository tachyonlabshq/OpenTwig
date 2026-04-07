use keyring::Entry;
use anyhow::Result;

const SERVICE_GITSERVER: &str = "com.thekozugroup.opentwig.gitserver";
const SERVICE_AI: &str = "com.thekozugroup.opentwig.ai";
const AI_KEY_USER: &str = "anthropic";

pub fn save_token(server_id: &str, token: &str) -> Result<()> {
    Entry::new(SERVICE_GITSERVER, server_id)?.set_password(token)?;
    Ok(())
}
pub fn load_token(server_id: &str) -> Result<Option<String>> {
    match Entry::new(SERVICE_GITSERVER, server_id)?.get_password() {
        Ok(t) => Ok(Some(t)),
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(e) => Err(e.into()),
    }
}
pub fn delete_token(server_id: &str) -> Result<()> {
    let entry = Entry::new(SERVICE_GITSERVER, server_id)?;
    match entry.delete_credential() {
        Ok(_) | Err(keyring::Error::NoEntry) => Ok(()),
        Err(e) => Err(e.into()),
    }
}
pub fn save_ai_key(key: &str) -> Result<()> {
    Entry::new(SERVICE_AI, AI_KEY_USER)?.set_password(key)?; Ok(())
}
pub fn load_ai_key() -> Result<Option<String>> {
    match Entry::new(SERVICE_AI, AI_KEY_USER)?.get_password() {
        Ok(t) => Ok(Some(t)),
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(e) => Err(e.into()),
    }
}
