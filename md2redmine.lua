--
-- Invoke with: pandoc -t md2redmine.lua input.md -o output.redmine
--

local pipe = pandoc.pipe
local stringify = (require "pandoc.utils").stringify

-- configure the writer.
function Writer(doc, opts)
  local meta = doc.meta

  -- Chose the image format based on the value of the
  -- `image_format` meta value.
  local image_format = meta.image_format
    and stringify(meta.image_format)
    or "png"
  local image_mime_type = ({
      jpeg = "image/jpeg",
      jpg = "image/jpeg",
      gif = "image/gif",
      png = "image/png",
      svg = "image/svg+xml",
    })[image_format]
    or error("unsupported image format `" .. img_format .. "`")
  return pandoc.write_classic(doc, opts)
end

-- Character escaping
local function escape(s, in_attribute)
  return s
end

local bullets = {}

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
  return bullets[1] and "\n" or "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add(body)
  if #notes > 0 then
    add('<ol class="footnotes">')
    for _,note in pairs(notes) do
      add(note)
    end
    add('</ol>')
  end
  return table.concat(buffer,'\n') .. '\n'
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
  return s
end

function Space()
  return " "
end

function SoftBreak()
  return "\n"
end

function LineBreak()
  return "---"
end

function Emph(s)
  return "*" .. s .. "*"
end

function Strong(s)
  return "*" .. s .. "*"
end

function Subscript(s)
  return "<sub>" .. s .. "</sub>"
end

function Superscript(s)
  return "<sup>" .. s .. "</sup>"
end

function SmallCaps(s)
  return '<span style="font-variant: small-caps;">' .. s .. '</span>'
end

function Strikeout(s)
  return '-' .. s .. '-'
end

function Link(s, src, tit, attr)
  return "\"" .. s .. "\":" .. escape(src, true)
end

function Image(s, src, tit, attr)
  return "!" .. src .. "!"
end

function Code(s, attr)
  return "<code" .. attributes(attr) .. ">" .. escape(s) .. "</code>"
end

function InlineMath(s)
  return "\\(" .. escape(s) .. "\\)"
end

function DisplayMath(s)
  return "\\[" .. escape(s) .. "\\]"
end

function SingleQuoted(s)
  return "&lsquo;" .. s .. "&rsquo;"
end

function DoubleQuoted(s)
  return "&ldquo;" .. s .. "&rdquo;"
end

function Note(s)
  local num = #notes + 1
  -- insert the back reference right before the final closing tag.
  s = string.gsub(s,
          '(.*)</', '%1 <a href="#fnref' .. num ..  '">&#8617;</a></')
  -- add a list item with the note to the note table.
  table.insert(notes, '<li id="fn' .. num .. '">' .. s .. '</li>')
  -- return the footnote reference, linked to the note.
  return '<a id="fnref' .. num .. '" href="#fn' .. num ..
            '"><sup>' .. num .. '</sup></a>'
end

function Span(s, attr)
  return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
end

function RawInline(format, str)
  if format == "html" then
    return str
  else
    return ''
  end
end

function Cite(s, cs)
  local ids = {}
  for _,cit in ipairs(cs) do
    table.insert(ids, cit.citationId)
  end
  return "<span class=\"cite\" data-citation-ids=\"" .. table.concat(ids, ",") ..
    "\">" .. s .. "</span>"
end

function Plain(s)
  return s
end

function Para(s)
  if string.lower(s) == "[toc]" then
      return "{{toc}}"
  else
      return s
  end
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
  return "h" .. lev .. ". " .. s
end

function BlockQuote(s)
  return "bq. " .. s
end

function HorizontalRule()
  return "---"
end

function LineBlock(ls)
  return '<div style="white-space: pre-line;">' .. table.concat(ls, '\n') ..
         '</div>'
end

function CodeBlock(s, attr)
    return "<pre><code" .. attributes(attr) .. ">" .. s ..  "\n</code></pre>"
end

function BulletList_(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, table.concat(bullets) .. ' ' .. item)
  end
  table.remove(bullets)
  return table.concat(buffer, "\n")
end

function OrderedList_(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, table.concat(bullets) .. " " .. item)
  end
  table.remove(bullets)
  return table.concat(buffer, "\n")
end

function DefinitionList(items)
  local buffer = {}
  for _,item in pairs(items) do
    local k, v = next(item)
    table.insert(buffer, "<dt>" .. k .. "</dt>\n<dd>" ..
                   table.concat(v, "</dd>\n<dd>") .. "</dd>")
  end
  return "<dl>\n" .. table.concat(buffer, "\n") .. "\n</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

function CaptionedImage(src, tit, caption, attr)
  -- return "!" .. src.replace(/^\/+/g, '') .. "!"
  return "!" .. string.gsub(src, '^/', '') .. "!"
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add("|")
  for i, h in pairs(headers) do
      add("_. " .. h .. "|")
  end
  add("\n")
  for _, row in pairs(rows) do
      add("|")
      for i, c in pairs(row) do
          add(c .. "|")
      end
      add("\n")
   end
  return table.concat(buffer, '')
end

function RawBlock(format, str)
  if format == "html" then
    return str
  else
    return ''
  end
end

function Div(s, attr)
  return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    if key == 'BulletList' then
        table.insert(bullets, '*')
        return BulletList_
    elseif key == 'OrderedList' then
        table.insert(bullets, '#')
        return OrderedList_
    end
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return "" end
  end
setmetatable(_G, meta)
