local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local conf = require "telescope.config".values
local sorters = require "telescope.sorters"
local previewers = require "octo.telescope.previewers"
local reviews = require "octo.reviews"
local gh = require "octo.api.gitlab.glab"
local utils = require "octo.utils"
local navigation = require "octo.navigation"
local graphql = require "octo.api.gitlab.graphql"
local entry_maker = require "octo.telescope.entry_maker"

local M = {}

local dropdown_opts = require('telescope.themes').get_dropdown({
  layout_config = {
    width = 0.4;
    height = 15;
  };
  prompt_title = false;
  results_title = false;
  previewer = false;
  borderchars = {
    results =  {'▔', '▕', '▁', '▏', '🭽', '🭾', '🭿', '🭼' };
    prompt =  {'▔', '▕', '▁', '▏', '🭽', '🭾', '🭿', '🭼' };
  };
})

-- this returns args to be put in the graphql query as string
-- opts is a table with the field and value
-- filter returned is a string of ", field1: value1, field2: value2"
local function get_filter(opts, kind)
  local filter = ""
  local allowed_values = {}
  if kind == "issue" then
    allowed_values = {"since", "createdBy", "assignee", "mentioned", "labels", "milestone", "states"}
  elseif kind == "pull_request" then
    allowed_values = {"baseRefName", "headRefName", "labels", "states"}
  elseif kind == "merge_request" then
    allowed_values = {"state"}
  end

  for _, value in pairs(allowed_values) do
    if opts[value] then
      local val
      if #vim.split(opts[value], ",") > 1 then
        -- list
        val = vim.split(opts[value], ",")
      else
        -- string
        val = opts[value]
      end
      val = vim.fn.json_encode(val)
      val = string.gsub(val, '"OPEN"', "OPEN")
      val = string.gsub(val, '"opened"', "opened")
      val = string.gsub(val, '"CLOSED"', "CLOSED")
      val = string.gsub(val, '"MERGED"', "MERGED")
      filter = filter .. value .. ":" .. val .. ","
    end
  end

  return filter
end

local function open(repo, what, command)
  return function(prompt_bufnr)
    local selection = action_state.get_selected_entry(prompt_bufnr)
    actions.close(prompt_bufnr)
    if command == 'default' then
      vim.cmd [[:buffer %]]
    elseif command == 'horizontal' then
      vim.cmd [[:sbuffer %]]
    elseif command == 'vertical' then
      vim.cmd [[:vert sbuffer %]]
    elseif command == 'tab' then
      vim.cmd [[:tab sb %]]
    end
    vim.cmd(string.format([[ lua require'octo.utils'.get_%s('%s', '%s') ]], what, repo, selection.value))
  end
end

local function open_preview_buffer(command)
  return function(prompt_bufnr)
    actions.close(prompt_bufnr)
    local preview_bufnr = require "telescope.state".get_global_key("last_preview_bufnr")
    if command == 'default' then
      vim.cmd(string.format(":buffer %d", preview_bufnr))
    elseif command == 'horizontal' then
      vim.cmd(string.format(":sbuffer %d", preview_bufnr))
    elseif command == 'vertical' then
      vim.cmd(string.format(":vert sbuffer %d", preview_bufnr))
    elseif command == 'tab' then
      vim.cmd(string.format(":tab sb %d", preview_bufnr))
    end

    vim.cmd [[stopinsert]]
  end
end

local function open_in_browser(kind, repo)
  return function(prompt_bufnr)
    local entry = action_state.get_selected_entry(prompt_bufnr)
    local number
    if kind == "repo" then
      repo = entry.repo.nameWithOwner
    else
      number = entry.value
    end
    actions.close(prompt_bufnr)
    navigation.open_in_browser(kind, repo, number)
  end
end

local function copy_url(kind)
  return function(prompt_bufnr)
    local entry = action_state.get_selected_entry(prompt_bufnr)
    local url = entry[kind].url
    vim.fn.setreg('+', url, 'c')
    vim.notify("[Octo] Copied '" .. url .. "' to the system clipboard (+ register)", 1)
  end
end

local function checkout_merge_request()
  return function(prompt_bufnr)
    local selection = action_state.get_selected_entry(prompt_bufnr)
    actions.close(prompt_bufnr)
    local sourceBranch = selection.merge_request.sourceBranch
    utils.checkout_pr(sourceBranch)
  end
end

function M.merge_requests(opts)
  opts = opts or {}
  if not opts.states then
    opts.state = "opened"
  end
  local filter = get_filter(opts, "merge_request")

  if not opts.repo or opts.repo == vim.NIL then
    opts.repo = utils.get_remote_name()
  end
  if not opts.repo then
    vim.notify("[Octo] Cannot find repo", 2)
    return
  end

  local owner, name = utils.split_repo(opts.repo)
  local query = graphql("merge_requests_query", owner, name, filter, {escape = false})
  print("Fetching merge requests (this may take a while) ...")
  gh.run(
    {
      args = {"api", "graphql", "--paginate", "-f", string.format("query=%s", query)},
      cb = function(output, stderr)
        print(" ")
        if stderr and not utils.is_blank(stderr) then
          vim.notify(stderr, 2)
        elseif output then
          local resp = utils.aggregate_pages(output, "data.project.mergeRequests.nodes")
          local merge_requests = resp.data.project.mergeRequests.nodes
          if #merge_requests == 0 then
            vim.notify(string.format("There are no matching merge requests in %s.", opts.repo), 2)
            return
          end
          local max_number = -1
          for _, merge_request in ipairs(merge_requests) do
            if #tostring(merge_request.iid) > max_number then
              max_number = #tostring(merge_request.iid)
            end
          end
          opts.preview_title = opts.preview_title or ''
          opts.prompt_title = opts.prompt_title or ''
          opts.results_title = opts.results_title or ''
          pickers.new(
            opts,
            {
              finder = finders.new_table {
                results = merge_requests,
                entry_maker = entry_maker.gen_from_merge_request(max_number)
              },
              sorter = conf.generic_sorter(opts),
              previewer = previewers.merge_request.new(opts),
              attach_mappings = function(_, map)
                action_set.select:replace(function(prompt_bufnr, type)
                  open(opts.repo, "merge_request", type)(prompt_bufnr)
                end)
                map("i", "<c-o>", checkout_merge_request())
                --map("i", "<c-b>", open_in_browser("pr", opts.repo))
                --map("i", "<c-y>", copy_url("pull_request"))
                return true
              end
            }
          ):find()
        end
      end
    }
  )
end

--
-- COMMITS
--
function M.commits()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer or not buffer:isPullRequest() then return end
  -- TODO: graphql
  local url = string.format("repos/%s/pulls/%d/commits", buffer.repo, buffer.number)
  gh.run(
    {
      args = {"api", url},
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          vim.notify(stderr, 2)
        elseif output then
          local results = vim.fn.json_decode(output)
          pickers.new(
            {},
            {
              prompt_title = false,
              results_title = false,
              preview_title = false,
              finder = finders.new_table {
                results = results,
                entry_maker = entry_maker.gen_from_git_commits()
              },
              sorter = conf.generic_sorter({}),
              previewer = previewers.commit.new({repo = buffer.repo}),
              attach_mappings = function()
                action_set.select:replace(function(prompt_bufnr, type)
                  open_preview_buffer(type)(prompt_bufnr)
                end)
                return true
              end
            }
          ):find()
        end
      end
    }
  )
end

--
-- FILES
--
function M.changed_files()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer or not buffer:isPullRequest() then return end
  local url = string.format("repos/%s/pulls/%d/files", buffer.repo, buffer.number)
  gh.run(
    {
      args = {"api", url},
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          vim.notify(stderr, 2)
        elseif output then
          local results = vim.fn.json_decode(output)
          pickers.new(
            {},
            {
              prompt_title = false,
              results_title = false,
              preview_title = false,
              finder = finders.new_table {
                results = results,
                entry_maker = entry_maker.gen_from_git_changed_files()
              },
              sorter = conf.generic_sorter({}),
              previewer = previewers.changed_files.new({repo = buffer.repo, number = buffer.number}),
              attach_mappings = function()
                action_set.select:replace(function(prompt_bufnr, type)
                  open_preview_buffer(type)(prompt_bufnr)
                end)
                return true
              end
            }
          ):find()
        end
      end
    }
  )
end

---
-- SEARCH
---
function M.pull_request_search(opts)
  opts = opts or {}

  if not opts.repo or opts.repo == vim.NIL then
    opts.repo = utils.get_remote_name()
  end
  if not opts.repo then
    vim.notify("[Octo] Cannot find repo", 2)
    return
  end
  local queue = {}
  opts.preview_title = opts.preview_title or ''
  opts.prompt_title = opts.prompt_title or ''
  opts.results_title = opts.results_title or ''
  pickers.new(
    opts,
    {
      finder = function(prompt, process_result, process_complete)
        if not prompt or prompt == "" then
          return nil
        end
        prompt = prompt

        -- skip requests for empty prompts
        if utils.is_blank(prompt) then
          process_complete()
          return
        end

        -- store prompt in request queue
        table.insert(queue, prompt)

        -- defer api call so that finder finishes and takes more keystrokes
        vim.defer_fn(function()

          -- do not process response, if this is not the last request we sent
          if prompt ~= queue[#queue] then
            process_complete()
            return
          end

          local query = graphql("search_pull_requests_query", opts.repo, prompt)
          gh.run(
            {
              args = {"api", "graphql", "-f", string.format("query=%s", query)},
              cb = function(output, stderr)

                -- do not process response, if this is not the last request we sent
                if prompt ~= queue[#queue] then
                  process_complete()
                  return
                end

                if stderr and not utils.is_blank(stderr) then
                  vim.notify(stderr, 2)
                elseif output then
                  local resp = vim.fn.json_decode(output)
                  for _, pull_request in ipairs(resp.data.search.nodes) do
                    process_result(entry_maker.gen_from_pull_request(6)(pull_request))
                  end
                  process_complete()
                end
              end
            }
          )
        end, 500)
      end,
      sorter = conf.generic_sorter(opts),
      previewer = previewers.pull_request.new(opts),
      attach_mappings = function(_, map)
        action_set.select:replace(function(prompt_bufnr, type)
          open(opts.repo, "pull_request", type)(prompt_bufnr)
        end)
        map("i", "<c-b>", open_in_browser("pr", opts.repo))
        map("i", "<c-y>", copy_url("pull_request"))
        return true
      end
    }
  ):find()
end

---
-- REVIEW COMMENTS
---
function M.pending_threads(threads)
  local max_linenr_length = -1
  for _, thread in ipairs(threads) do
    max_linenr_length = math.max(max_linenr_length, #tostring(thread.startLine))
    max_linenr_length = math.max(max_linenr_length, #tostring(thread.line))
  end
  pickers.new(
    {},
    {
      prompt_title = false,
      results_title = false,
      preview_title = false,
      finder = finders.new_table {
        results = threads,
        entry_maker = entry_maker.gen_from_review_thread(max_linenr_length)
      },
      sorter = conf.generic_sorter({}),
      previewer = previewers.review_thread.new({}),
      attach_mappings = function()
        actions.select_default:replace(function(prompt_bufnr)
          local thread = action_state.get_selected_entry(prompt_bufnr).thread
          actions.close(prompt_bufnr)
          reviews.jump_to_pending_review_thread(thread)
        end)
        return true
      end
    }
  ):find()
end

---
-- PROJECTS
---
function M.repos(opts)
  opts = opts or {}
  if not opts.login then
    opts.login = vim.g.octo_viewer
  end

  local query = graphql("repos_query", opts.login)
  print("Fetching repositories (this may take a while) ...")
  gh.run(
    {
      args = {"api", "graphql", "--paginate", "-f", string.format("query=%s", query)},
      cb = function(output, stderr)
        print(" ")
        if stderr and not utils.is_blank(stderr) then
          vim.notify(stderr, 2)
        elseif output then
          local resp = utils.aggregate_pages(output, "data.repositoryOwner.repositories.nodes")
          local repos = resp.data.repositoryOwner.repositories.nodes
          if #repos == 0 then
            vim.notify(string.format("There are no matching repositories for %s.", opts.login), 2)
            return
          end
          local max_nameWithOwner = -1
          local max_forkCount = -1
          local max_stargazerCount = -1
          for _, repo in ipairs(repos) do
            max_nameWithOwner = math.max(max_nameWithOwner, #repo.nameWithOwner)
            max_forkCount = math.max(max_forkCount, #tostring(repo.forkCount))
            max_stargazerCount = math.max(max_stargazerCount, #tostring(repo.stargazerCount))
          end
          opts.preview_title = opts.preview_title or ''
          opts.prompt_title = opts.prompt_title or ''
          opts.results_title = opts.results_title or ''
          pickers.new(
            opts,
            {
              finder = finders.new_table {
                results = repos,
                entry_maker = entry_maker.gen_from_repo(max_nameWithOwner, max_forkCount, max_stargazerCount)
              },
              sorter = conf.generic_sorter(opts),
              attach_mappings = function(_, map)
                action_set.select:replace(function(prompt_bufnr, type)
                  open(opts.repo, "repo", type)(prompt_bufnr)
                end)
                map("i", "<c-b>", open_in_browser("repo"))
                map("i", "<c-y>", copy_url("repo"))
                return true
              end
            }
          ):find()
        end
      end
    }
  )
end

return M
