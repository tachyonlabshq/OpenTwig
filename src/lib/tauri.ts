import { invoke } from '@tauri-apps/api/core';

export type GitServerKind = 'github' | 'gitlab' | 'gitea' | 'bitbucket' | 'custom';
export type AuthMethod = 'token' | 'ssh' | 'oauth';

export interface GitServer {
  id: string;
  kind: GitServerKind;
  display_name: string;
  base_url: string;
  web_url: string;
  auth_method: AuthMethod;
}

export interface GitServerPreset {
  kind: string;
  display_name: string;
  base_url: string;
  web_url: string;
}

export interface Project {
  id: string;
  name: string;
  local_path: string;
  remote_url: string;
  git_server_id: string;
  current_branch: string;
  created_at: number;
  last_opened_at: number;
}

export interface GitStatus {
  branch: string;
  ahead: number;
  behind: number;
  staged: string[];
  unstaged: string[];
  untracked: string[];
}

export interface BranchList {
  local: string[];
  remote: string[];
  current: string;
}

export interface DocumentEntry {
  path: string;
  name: string;
  is_dir: boolean;
  size: number;
  modified: number;
}

export interface AddServerParams {
  kind: string;
  displayName: string;
  baseUrl: string;
  webUrl: string;
  authMethod: string;
  token?: string;
}

export const tauri = {
  git: {
    clone: (url: string, path: string, serverId: string) =>
      invoke<void>('git_clone', { url, path, serverId }),
    status: (path: string) => invoke<GitStatus>('git_status', { path }),
    commit: (path: string, message: string, author: string, email: string) =>
      invoke<string>('git_commit', { path, message, author, email }),
    push: (path: string) => invoke<void>('git_push', { path }),
    pull: (path: string) => invoke<void>('git_pull', { path }),
    branches: (path: string) => invoke<BranchList>('git_branches', { path }),
    checkout: (path: string, branch: string) =>
      invoke<void>('git_checkout', { path, branch }),
  },
  project: {
    create: (name: string, localPath: string, gitServerId: string, remoteUrl: string) =>
      invoke<Project>('project_create', { name, localPath, gitServerId, remoteUrl }),
    list: () => invoke<Project[]>('project_list'),
    open: (id: string) => invoke<Project>('project_open', { id }),
    delete: (id: string) => invoke<void>('project_delete', { id }),
    documents: (id: string) => invoke<DocumentEntry[]>('project_documents', { id }),
  },
  gitServer: {
    add: (params: AddServerParams) => invoke<GitServer>('git_server_add', params as unknown as Record<string, unknown>),
    list: () => invoke<GitServer[]>('git_server_list'),
    delete: (id: string) => invoke<void>('git_server_delete', { id }),
    test: (id: string) => invoke<boolean>('git_server_test', { id }),
    presets: () => invoke<GitServerPreset[]>('git_server_presets'),
  },
  ai: {
    saveKey: (key: string) => invoke<void>('ai_save_key', { key }),
    hasKey: () => invoke<boolean>('ai_has_key'),
  },
  document: {
    read: (path: string) => invoke<string>('document_read', { path }),
    write: (path: string, content: string) =>
      invoke<void>('document_write', { path, content }),
    create: (projectPath: string, filename: string) =>
      invoke<DocumentEntry>('document_create', { projectPath, filename }),
  },
};

export async function safeInvoke<T>(fn: () => Promise<T>, fallback: T): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    console.warn('tauri call failed', e);
    return fallback;
  }
}
