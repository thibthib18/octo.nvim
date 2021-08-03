local M = {}

M.merge_requests_query =
  [[
query($endCursor: String) {
  project(fullPath: "%s/%s"){
    mergeRequests(first: 10, after: $endCursor, %s) {
      nodes {
        iid
        title
        webUrl
        state
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

-- https://docs.github.com/en/free-pro-team@latest/graphql/reference/objects#pullrequest
M.merge_request_query =
  [[
query {
  project(fullPath: "%s/%s"){
    mergeRequest(iid: "%d") {
      id
      iid
      state
      title
      commitCount
      description
      createdAt
      updatedAt
      diffStatsSummary {
        additions
        deletions
        changes
        fileCount
      }
      webUrl
      assignees(first: 10){
        nodes {
          id
          name
          username
        }
      }
      userPermissions {
        updateMergeRequest
      }
      diffStats{
        path
        additions
        deletions
      }
      mergeUser {
        id
      }
      participants(first:10) {
        nodes {
          id
        }
      }
      commitCount

      author {
        id
        name
        username
      }
      labels{
        nodes {
          title
          color
        }
      }
      reviewers(first:10){
        nodes {
          name
          mergeRequestInteraction {
            reviewState
          }
        }
      }
      mergeUser {
        name
      }
    }
  }
}
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

