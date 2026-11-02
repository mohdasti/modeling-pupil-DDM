-- Quarto does not index a heading that carries the unnumbered class, and
-- then warns that @sec-supp-spec is unresolved. Rewrite that citation
-- into a link before Quarto's cross-reference step sees it. The link
-- text is the section title.
local TITLE = "Model specification and estimation"

function Cite(el)
  if #el.citations ~= 1 or el.citations[1].id ~= "sec-supp-spec" then
    return nil
  end
  return pandoc.Link({ pandoc.Str(TITLE) }, "#sec-supp-spec")
end
