export { initSupabase, getSupabase, _resetSupabase, type SupportedStorage } from './supabase';
export { initPlatform, getPlatform } from './config';
export { createWebSessionStorageAdapter, type StorageAdapter } from './storage';

export {
  fetchWritingProjects,
  fetchWritingProject,
  createWritingProject,
  updateWritingProject,
  deleteWritingProject,
  seedEssayProject,
  saveProjectContent,
  saveProjectPages,
  saveProjectHighlights,
  fetchAssistantConversation,
  saveAssistantConversation,
  startAssistantStream,
  generateShortId,
  generateSlug,
  publishProject,
  unpublishProject,
  fetchPublishedEssay,
  updatePublishSettings,
} from './writing';

export type {
  WritingStatus,
  WritingProject,
  WritingProjectRow,
  AssistantMessage,
  Highlight,
  PublishedEssay,
} from './writing';
