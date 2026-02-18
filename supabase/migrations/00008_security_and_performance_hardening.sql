-- Migration: Security & Performance Hardening
-- Applied: 2026-02-18 to staging (jrqajnmudggfyghmyrun) and production (oddczcritnsiahruqqaw)
-- Note: Production was applied with adapted SQL (different policy names, feedback joins
--   through drafts, assistant_conversations uses single ALL policy, extra
--   public.update_updated_at_column function). This file reflects staging schema.
-- Fixes:
--   1. Pin search_path on public functions (prevents search_path injection)
--   2. Wrap auth.uid() in (select ...) in all RLS policies (InitPlan optimization)
--   3. Add missing index on message_usage.project_id

BEGIN;

-- =============================================================================
-- 1. Pin function search paths
-- =============================================================================

-- set_updated_at() — trigger function, no SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path = ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

-- use_invite_code(text) — SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.use_invite_code(code_input text)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $function$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE public.invite_codes
  SET current_uses = current_uses + 1
  WHERE code = code_input AND current_uses < max_uses;
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count > 0;
END;
$function$;

-- rollback_invite_code(text) — SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.rollback_invite_code(code_input text)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $function$
BEGIN
  UPDATE public.invite_codes
  SET current_uses = GREATEST(current_uses - 1, 0)
  WHERE code = code_input;
END;
$function$;

-- =============================================================================
-- 2. Wrap auth.uid() in (select auth.uid()) for RLS InitPlan optimization
-- =============================================================================

-- ---- projects ----

DROP POLICY "Users can read own projects" ON public.projects;
CREATE POLICY "Users can read own projects" ON public.projects
  FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY "Users can insert own projects" ON public.projects;
CREATE POLICY "Users can insert own projects" ON public.projects
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY "Users can update own projects" ON public.projects;
CREATE POLICY "Users can update own projects" ON public.projects
  FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY "Users can delete own projects" ON public.projects;
CREATE POLICY "Users can delete own projects" ON public.projects
  FOR DELETE USING ((select auth.uid()) = user_id);

-- ---- brain_dumps ----

DROP POLICY "Users can read own brain_dumps" ON public.brain_dumps;
CREATE POLICY "Users can read own brain_dumps" ON public.brain_dumps
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = brain_dumps.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can insert own brain_dumps" ON public.brain_dumps;
CREATE POLICY "Users can insert own brain_dumps" ON public.brain_dumps
  FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = brain_dumps.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can update own brain_dumps" ON public.brain_dumps;
CREATE POLICY "Users can update own brain_dumps" ON public.brain_dumps
  FOR UPDATE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = brain_dumps.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can delete own brain_dumps" ON public.brain_dumps;
CREATE POLICY "Users can delete own brain_dumps" ON public.brain_dumps
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = brain_dumps.project_id
      AND projects.user_id = (select auth.uid())
  ));

-- ---- interviews ----

DROP POLICY "Users can read own interviews" ON public.interviews;
CREATE POLICY "Users can read own interviews" ON public.interviews
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = interviews.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can insert own interviews" ON public.interviews;
CREATE POLICY "Users can insert own interviews" ON public.interviews
  FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = interviews.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can update own interviews" ON public.interviews;
CREATE POLICY "Users can update own interviews" ON public.interviews
  FOR UPDATE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = interviews.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can delete own interviews" ON public.interviews;
CREATE POLICY "Users can delete own interviews" ON public.interviews
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = interviews.project_id
      AND projects.user_id = (select auth.uid())
  ));

-- ---- drafts ----

DROP POLICY "Users can read own drafts" ON public.drafts;
CREATE POLICY "Users can read own drafts" ON public.drafts
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = drafts.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can insert own drafts" ON public.drafts;
CREATE POLICY "Users can insert own drafts" ON public.drafts
  FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = drafts.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can update own drafts" ON public.drafts;
CREATE POLICY "Users can update own drafts" ON public.drafts
  FOR UPDATE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = drafts.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can delete own drafts" ON public.drafts;
CREATE POLICY "Users can delete own drafts" ON public.drafts
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = drafts.project_id
      AND projects.user_id = (select auth.uid())
  ));

-- ---- feedback ----

DROP POLICY "Users can read own feedback" ON public.feedback;
CREATE POLICY "Users can read own feedback" ON public.feedback
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = feedback.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can insert own feedback" ON public.feedback;
CREATE POLICY "Users can insert own feedback" ON public.feedback
  FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = feedback.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can update own feedback" ON public.feedback;
CREATE POLICY "Users can update own feedback" ON public.feedback
  FOR UPDATE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = feedback.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can delete own feedback" ON public.feedback;
CREATE POLICY "Users can delete own feedback" ON public.feedback
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = feedback.project_id
      AND projects.user_id = (select auth.uid())
  ));

-- ---- assistant_conversations ----

DROP POLICY "Users can read own assistant_conversations" ON public.assistant_conversations;
CREATE POLICY "Users can read own assistant_conversations" ON public.assistant_conversations
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = assistant_conversations.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can insert own assistant_conversations" ON public.assistant_conversations;
CREATE POLICY "Users can insert own assistant_conversations" ON public.assistant_conversations
  FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = assistant_conversations.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can update own assistant_conversations" ON public.assistant_conversations;
CREATE POLICY "Users can update own assistant_conversations" ON public.assistant_conversations
  FOR UPDATE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = assistant_conversations.project_id
      AND projects.user_id = (select auth.uid())
  ));

DROP POLICY "Users can delete own assistant_conversations" ON public.assistant_conversations;
CREATE POLICY "Users can delete own assistant_conversations" ON public.assistant_conversations
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.projects
    WHERE projects.id = assistant_conversations.project_id
      AND projects.user_id = (select auth.uid())
  ));

-- ---- user_profiles ----

DROP POLICY "Users can read own profile" ON public.user_profiles;
CREATE POLICY "Users can read own profile" ON public.user_profiles
  FOR SELECT USING ((select auth.uid()) = id);

-- ---- message_usage ----

DROP POLICY "Users can read own usage" ON public.message_usage;
CREATE POLICY "Users can read own usage" ON public.message_usage
  FOR SELECT USING ((select auth.uid()) = user_id);

-- ---- user_mcp_servers ----

DROP POLICY "Users can read own mcp servers" ON public.user_mcp_servers;
CREATE POLICY "Users can read own mcp servers" ON public.user_mcp_servers
  FOR SELECT USING ((select auth.uid()) = user_id);

-- =============================================================================
-- 3. Add missing index on message_usage.project_id
-- =============================================================================

CREATE INDEX IF NOT EXISTS message_usage_project_id_idx
  ON public.message_usage (project_id);

COMMIT;
