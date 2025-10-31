# Task 6.3: Quick Testing Guide

## Quick Console Test

Test the epic dashboard from Rails console:

```ruby
# 1. Ensure you have a user and repository
user = User.first || User.create!(email: 'test@example.com', password: 'password123')
repo = Repository.first || Repository.create!(
  user: user, 
  name: 'test-repo', 
  github_url: 'https://github.com/user/test-repo'
)

# 2. Create an epic with tasks
tasks = [
  "Task 1: Add user authentication",
  "Task 2: Create dashboard UI",
  "Task 3: Deploy to production"
]

result = Epics::CreateFromManualSpec.run!(
  user: user,
  repository: repo,
  tasks_json: tasks.to_json,
  base_branch: "main"
)

epic = result[:epic]
puts "✅ Created Epic ##{epic.id}: #{epic.title}"
puts "   View at: http://localhost:3000/epics/#{epic.id}"

# 3. Simulate different task states for testing UI
task1, task2, task3 = epic.tasks.ordered

# Task 1: Running
task1.update!(
  status: :running,
  branch_name: "cursor-agent/task-1-abc123"
)

# Task 2: PR Open with link
task2.update!(
  status: :pr_open,
  pull_request_url: "https://github.com/user/repo/pull/123",
  branch_name: "cursor-agent/task-2-def456"
)

# Task 3: Keep as pending

puts "\n📋 Task States:"
puts "   Task 1: #{task1.status} (#{task1.branch_name})"
puts "   Task 2: #{task2.status} (#{task2.pull_request_url})"
puts "   Task 3: #{task3.status}"

puts "\n✅ Ready to test! Visit: http://localhost:3000/epics/#{epic.id}"
```

## Expected Dashboard Display

When you visit the epic page, you should see:

### Header Section
- **Epic Title**: e.g., "Epic #123: test-repo @ main"
- **Status Badge**: "Pending" (gray badge)
- **Repository**: "test-repo"
- **Base Branch**: "main"

### Tasks Section
Three task cards showing:

1. **Task #1**
   - Status: "Running" (yellow badge)
   - Description: "Task 1: Add user authentication"
   - Branch: `cursor-agent/task-1-abc123`

2. **Task #2**
   - Status: "Pr open" (purple badge)
   - Description: "Task 2: Create dashboard UI"
   - PR Link: "View Pull Request →" (clickable, opens in new tab)
   - Branch: `cursor-agent/task-2-def456`

3. **Task #3**
   - Status: "Pending" (gray badge)
   - Description: "Task 3: Deploy to production"

### Action Buttons
- **Start Epic** (disabled button with tooltip)
- **Refresh** (reloads the page)
- **Create Another Epic** (links to /epics/new)

## Testing Different Scenarios

### Test Epic in Different States

```ruby
# Test with running epic
epic.update!(status: :running)
# Refresh browser to see yellow "Running" badge on epic

# Test with completed epic
epic.update!(status: :completed)
# Refresh browser - Start Epic button should be hidden

# Reset to pending
epic.update!(status: :pending)
```

### Test All Task States

```ruby
epic.tasks.each_with_index do |task, i|
  status = [:pending, :running, :pr_open, :merging, :completed, :failed][i % 6]
  task.update!(status: status)
end
# Refresh browser to see all different badge colors
```

### Test Without PR Links

```ruby
epic.tasks.each { |t| t.update!(pull_request_url: nil) }
# Refresh browser - PR links should not appear
```

## Manual UI Verification Checklist

Visit the epic page and verify:

- [ ] Epic title displays correctly
- [ ] Epic status badge shows with correct color
- [ ] Repository name is visible
- [ ] Base branch is visible
- [ ] Task count displays (e.g., "Tasks (3)")
- [ ] All tasks are listed in order
- [ ] Task position numbers are correct (#1, #2, #3)
- [ ] Task status badges show with correct colors
- [ ] Task descriptions are readable
- [ ] PR links appear when URLs are present
- [ ] PR links open in new tab
- [ ] Branch names display when present
- [ ] Branch names are in monospace font
- [ ] Start Epic button shows for pending epics
- [ ] Start Epic button is disabled (not clickable yet)
- [ ] Start Epic button has tooltip on hover
- [ ] Refresh button is clickable
- [ ] Refresh button reloads the page
- [ ] Create Another Epic button links to /epics/new
- [ ] Layout is responsive and clean
- [ ] No visual glitches or overlapping text

## Browser Test

```bash
# Start Rails server
bin/dev

# Visit in browser
# http://localhost:3000/epics/new
# 1. Create an epic with 3 tasks
# 2. Submit the form
# 3. You'll be redirected to the show page
# 4. Verify all elements appear correctly
# 5. Click Refresh - page should reload
# 6. Hover over Start Epic - tooltip should show
```

## Status Color Reference

| Status | Color | Badge Example |
|--------|-------|---------------|
| Pending | Gray | ![gray badge] |
| Generating Spec | Blue | ![blue badge] |
| Running | Yellow | ![yellow badge] |
| PR Open | Purple | ![purple badge] |
| Merging | Indigo | ![indigo badge] |
| Completed | Green | ![green badge] |
| Paused | Orange | ![orange badge] |
| Failed | Red | ![red badge] |

## Troubleshooting

### Epic not found
- Make sure you created an epic first via console or /epics/new

### Tasks not showing
- Verify tasks were created: `epic.tasks.count`
- Check task descriptions are not nil: `epic.tasks.pluck(:description)`

### PR link not showing
- Verify `pull_request_url` is set: `task.pull_request_url`
- URL must be a valid HTTP/HTTPS URL

### Start Epic button not showing
- Button only shows for pending epics: `epic.pending?`
- Check epic status: `epic.status`

### Colors not showing
- Verify Tailwind CSS is compiled
- Check browser console for CSS errors
- Restart Rails server if needed

## Success Criteria

✅ All elements display correctly
✅ Status badges show correct colors
✅ Manual refresh works
✅ PR links are clickable
✅ Start Epic button is visible but disabled
✅ Layout is clean and responsive

Task 6.3 is complete when all checklist items pass!
