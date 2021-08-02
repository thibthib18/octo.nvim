local menu = require'octo.telescope.menu'
local gitlabMenu = require'octo.telescope.gitlab-menu'
return require'telescope'.register_extension {
  exports = {
    commits = menu.commits,
    files = menu.changed_files,
    gists = menu.gists,
    issues = menu.issues,
    prs = menu.pull_requests,
    mrs = gitlabMenu.merge_requests,
    live_issues = menu.issue_search,
    live_prs = menu.pull_request_search
  },
}
