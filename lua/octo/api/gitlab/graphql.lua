local M = {}

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#resolvereviewthread
M.resolve_review_thread_mutation =
  [[
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#unresolvereviewthread
M.unresolve_review_thread_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreview
M.start_review_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#markfileasviewed
M.mark_file_as_viewed_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#unmarkfileasviewed
M.unmark_file_as_viewed_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreview
M.submit_pull_request_review_mutation =
  [[
]]

M.delete_pull_request_review_mutation =
[[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewthread
M.add_pull_request_review_thread_mutation =
[[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewthread
M.add_pull_request_review_multiline_thread_mutation =
[[
]]

-- https://docs.github.com/en/graphql/reference/mutations#updatepullrequestreviewcomment
M.update_pull_request_review_comment_mutation =
[[
]]

-- https://docs.github.com/en/graphql/reference/mutations#updatepullrequestreview
M.update_pull_request_review_mutation =
[[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewcomment
M.add_pull_request_review_comment_mutation =
[[
]]

-- M.add_pull_request_review_comment_mutation =
-- [[
--   mutation {
--     addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: "%s", body: "%s"}) {
--       comment{
--         id
--         body
--       }
--     }
--   }
-- ]]

-- https://docs.github.com/en/graphql/reference/mutations#deletepullrequestreviewcomment
M.delete_pull_request_review_comment_mutation =
  [[
]]


-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updatepullrequest
M.update_pull_request_mutation =
  [[
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/mutations#updatepullrequest
M.update_pull_request_state_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/objects#pullrequestreviewthread
M.pending_review_threads_query =
[[
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#pullrequestreviewthread
M.review_threads_query =
  [[
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#pullrequest
M.pull_request_query =
  [[
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#repository
M.repository_id_query = [[
]]

M.pull_requests_query =
  [[
]]

M.search_pull_requests_query =
  [[
]]

-- https://docs.github.com/en/graphql/reference/objects#project
M.projects_query =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addprojectcard
M.add_project_card_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#moveprojectcard
M.move_project_card_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#deleteprojectcard
M.delete_project_card_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#createlabel
-- requires application/vnd.github.bane-preview+json
M.create_label_mutation =
  [[
]]


-- https://docs.github.com/en/graphql/reference/mutations#removelabelsfromlabelable
M.add_labels_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#removelabelsfromlabelable
M.remove_labels_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/objects#label
M.labels_query =
  [[
]]

M.pull_request_labels_query =
  [[
]]

M.pull_request_assignees_query =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#addassigneestoassignable
M.add_assignees_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#removeassigneestoassignable
M.remove_assignees_mutation =
  [[
]]

-- https://docs.github.com/en/graphql/reference/mutations#requestreviews
-- for teams use `teamIds`
M.request_reviews_mutation =
  [[
]]

M.user_profile_query =
  [[
]]

M.changed_files_query =
  [[
]]

M.file_content_query =
  [[
]]

M.reactions_for_object_query =
  [[
]]

M.user_query =
  [[
]]

M.repos_query =
  [[
]]

M.repo_query =
  [[
]]


local function escape_chars(string)
  local escaped, _ = string.gsub(
    string,
    '["\\]',
    {
      ['"'] = '\\"',
      ['\\'] = '\\\\',
    }
  )
  return escaped
end

return function(query, ...)
  local opts = { escape = true }
  for _, v in ipairs{...} do
    if type(v) == "table" then
      opts = vim.tbl_deep_extend("force", opts, v)
      break
    end
  end
  local escaped = {}
  for _, v in ipairs{...} do
    if type(v) == "string" and opts.escape then
      local encoded = escape_chars(v)
      table.insert(escaped, encoded)
    else
      table.insert(escaped, v)
    end
  end
  return string.format(M[query], unpack(escaped))
end

