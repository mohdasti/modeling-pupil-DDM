-- PDF-only: give each column at least enough of the text width for its
-- longest unbreakable token (header or cell). Pandoc otherwise sizes
-- some columns from short body entries, and the header then sticks
-- into the margin.
function Table(tbl)
  local specs = tbl.colspecs
  local n = #specs
  if n < 2 then
    return nil
  end

  local function longest_token(el)
    local s = pandoc.utils.stringify(el)
    local m = 1
    for w in tostring(s):gmatch("%S+") do
      local len = utf8.len(w) or #w
      if len > m then
        m = len
      end
    end
    return m
  end

  local function consider(el, i, weight)
    if el and el.cells and el.cells[i] then
      return math.max(weight, longest_token(el.cells[i]))
    end
    return weight
  end

  local weights = {}
  local sum = 0
  for i = 1, n do
    local w = 1
    if tbl.head and tbl.head.rows then
      for _, row in ipairs(tbl.head.rows) do
        w = consider(row, i, w)
      end
    end
    if tbl.bodies then
      for _, body in ipairs(tbl.bodies) do
        for _, row in ipairs(body.body or {}) do
          w = consider(row, i, w)
        end
      end
    end
    if tbl.foot and tbl.foot.rows then
      for _, row in ipairs(tbl.foot.rows) do
        w = consider(row, i, w)
      end
    end
    -- Capitals in short headers (for example "ROPE") are wider than an
    -- average character, so a four-character column still overflows.
    weights[i] = math.max(w, 5)
    sum = sum + weights[i]
  end

  for i = 1, n do
    specs[i] = {specs[i][1], weights[i] / sum}
  end
  tbl.colspecs = specs
  return tbl
end
