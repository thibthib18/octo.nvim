
-- couldnt (or wouldnt) find a good explanation easily enough
-- so that's my test framework here


local M = {}

M.equal = function(first, second)
  if first ~= second then
    error(first .. ' is not equal to ' .. second)
  end
end


return M
