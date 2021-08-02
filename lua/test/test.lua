local glab = require"octo.api.gitlab.glab"
local graphql = require "octo.graphql"
local test = require "test.utils"

owner = 'thibthib18'
name = 'dotfiles'
number = 1
query = graphql("pull_request_query", owner, name, number)

print('******')
glab.run(
{
  args = {"api", "graphql", "--paginate", "-f", string.format("query=%s", query)},
  cb = function(output, stderr)
    local resp = vim.fn.json_decode(output)
    local title = resp.data.project.pullRequest.title
    print(title)
    --test.equal(title, "Nim builtin lsp")
    for key,value in pairs(resp.data.repository.pullRequest) do
      print("found member " .. key);
    end
  end
})
