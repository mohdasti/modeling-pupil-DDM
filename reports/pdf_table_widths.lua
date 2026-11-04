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

  -- A short label or a statistical result should set the column
  -- width. Longer text still wraps at spaces.
  local function cell_weight(el, is_header)
    local s = pandoc.utils.stringify(el)
    local full = utf8.len(s) or #s
    local token = 1
    for w in tostring(s):gmatch("%S+") do
      local len = utf8.len(w) or #w
      if len > token then
        token = len
      end
    end
    local weight = token
    if full > 0 and full <= 24 then
      weight = math.max(token, full)
    end
    -- Intervals are wider than a character count suggests, and a
    -- right-aligned one runs into the next column if the fit is exact.
    if s:find("%[") then
      weight = weight + 8
    end
    -- Short headers such as "In ROPE" and "ΔELPD ± SE" are wider
    -- than a lowercase string of the same length.
    if is_header and full > 0 and full <= 16 then
      weight = math.max(weight, full + 5)
    end
    return weight
  end

  local function consider(el, i, weight, is_header)
    if el and el.cells and el.cells[i] then
      return math.max(weight, cell_weight(el.cells[i], is_header))
    end
    return weight
  end

  local weights = {}
  local sum = 0
  for i = 1, n do
    local w = 1
    if tbl.head and tbl.head.rows then
      for _, row in ipairs(tbl.head.rows) do
        w = consider(row, i, w, true)
      end
    end
    if tbl.bodies then
      for _, body in ipairs(tbl.bodies) do
        for _, row in ipairs(body.body or {}) do
          w = consider(row, i, w, false)
        end
      end
    end
    if tbl.foot and tbl.foot.rows then
      for _, row in ipairs(tbl.foot.rows) do
        w = consider(row, i, w, false)
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
