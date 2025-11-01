Task: Implement base layout scaffolding
Create BaseLayout carrying shared html, head, flash messaging, and global body classes/attributes.
Move navbar into an authenticated-specific layout/controller that uses BaseLayout.
Update routing/controllers so authenticated pages inherit the new layout stack.
Acceptance Criteria: Unauthenticated pages render without navbar using BaseLayout; authenticated pages render with navbar via the authenticated layout; flashes and global body attributes work in both contexts; no layout regressions in existing views.

Task: Customize Devise sessions controller using base layout
Subclass Devise sessions controller.
Configure it to use the new base (non-authenticated) layout.
Ensure any custom views are updated accordingly.
Acceptance Criteria: Sign-in/out views render via BaseLayout without authenticated chrome; Devise routes still functional; controller covered by smoke specs or request tests.

Task: Extract webhook business logic into ApplicationInteractions
Identify business rules currently in webhooks_controller.rb.
Move each logical unit into dedicated ApplicationInteraction objects.
Wire controller to delegate to these interactions; add specs for interactions.
Acceptance Criteria: webhooks_controller.rb limited to request handling, invoking interactions; ApplicationInteraction specs cover success/failure paths; existing webhook behavior unchanged.

Task: Merge finished status via async job
Create an async job wrapping an ApplicationInteraction that merges the feature branch into the base branch when status is “finished”.
Ensure job enqueues from the status handler.
Add tests for job enqueueing and merge interaction.
Acceptance Criteria: Finished-status flow triggers background job; job delegates to interaction performing merge; unit/integration tests verify job scheduling and merge call; merge errors surfaced/logged appropriately.