-- Add optional subtitle field to projects
ALTER TABLE projects ADD COLUMN subtitle text DEFAULT '';
