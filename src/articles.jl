# Legit.jl -- Convert French law in LEGI format to Git & Markdown
# By: Emmanuel Raviart <emmanuel.raviart@data.gouv.fr>
#
# Copyright (C) 2015 Etalab
# https://github.com/etalab/Legit.jl
#
# The Legit.jl package is licensed under the MIT "Expat" License.


const number_by_latin_extension = @compat Dict{String, String}(
  "bis" => "0000020",
  "ter" => "0000030",
  "quater" => "0000040",
  "quinquies" => "0000050",
  "sexies" => "0000060",
  "septies" => "0000070",
  "octies" => "0000080",
  "nonies" => "0000090",
  "decies" => "0000100",
  "undecies" => "0000110",
  "duodecies" => "0000120",
  "terdecies" => "0000130",
  "quaterdecies" => "0000140",
  "quindecies" => "0000150",
  "quinquedecies" => "0000150",
  "sexdecies" => "0000160",
  "septdecies" => "0000170",
  "octodecies" => "0000180",
  "novodecies" => "0000190",
  "vicies" => "0000200",
  "unvicies" => "0000210",
  "duovicies" => "0000220",
  "tervicies" => "0000230",
  "quatervicies" => "0000240",
  "quinvicies" => "0000250",
  "sexvicies" => "0000260",
  "septvicies" => "0000270",
  "octovicies" => "0000280",
  "novovicies" => "0000290",
  "tricies" => "0000300",
  "untricies" => "0000310",
  "duotricies" => "0000320",
  "tertricies" => "0000330",
  "quatertricies" => "0000340",
  "quintricies" => "0000350",
  "sextricies" => "0000360",
  "septtricies" => "0000370",
  "octotricies" => "0000380",
  "novotricies" => "0000390",
)

const number_by_slug = @compat Dict{String, String}(
  "premier" => "0000010",
  "premiere" => "0000010",
  "deuxieme" => "0000020",
  "troisieme" => "0000030",
  "quatrieme" => "0000040",
  "cinquieme" => "0000050",
  "sixieme" => "0000060",
  "septieme" => "0000070",
  "huitieme" => "0000080",
  "neuvieme" => "0000090",
  "dixieme" => "0000100",
)


abstract Node
abstract AbstractTableOfContent <: Node


type RootNode <: Node
  title::String
end


@compat type Article <: Node
  container::AbstractTableOfContent
  start_date::Union(Date, Nothing)
  stop_date::Union(Date, Nothing)
  dict::Dict  # Dict{String, Any}
  next_version::Nullable{Article}  # Next version of the same article (may have the same ID)

  function Article(container::AbstractTableOfContent, start_date::Union(Date, Nothing), stop_date::Union(Date, Nothing),
      dict::Dict, next_version::Nullable{Article})
    article = new(container, start_date, stop_date, dict, next_version)
    finalizer(article, free!)
    return article
  end
end

Article(container::AbstractTableOfContent, start_date::Union(Date, Nothing), stop_date::Union(Date, Nothing),
  dict::Dict) = @compat Article(container, start_date, stop_date, dict, Nullable{Article}())


type Document <: AbstractTableOfContent
  container::Node  # TODO: SimpleNode or RootNode or Section
  texte_version::Dict  # Dict{String, Any}
  textelr::Dict  # Dict{String, Any}

  function Document(container::Node, texte_version::Dict, textelr::Dict)
    document = new(container, texte_version, textelr)
    finalizer(document, free!)
    return document
  end
end


type NonArticle <: Node
  container::AbstractTableOfContent
  kind::String
  title::String
  content::XMLElement
end


type Changed
  articles::Array{Union(Article, NonArticle)}
  deleted_articles::Array{Article}

  Changed() = new(Article[], Article[])
end


type Section <: Node
  short_title::String
  sortable_title::String
  title::String
  child_by_name::Dict{String, Node}

  Section(short_title::String, title::String) = new(short_title, node_sortable_title(short_title), title,
    @compat Dict{String, Node}())
end

Section(title::String) = Section(title, title)

Section() = Section("", "")


type SimpleNode <: Node
  container::Node
  title::String
end


type TableOfContent <: AbstractTableOfContent
  container::AbstractTableOfContent
  start_date::Union(Date, Nothing)
  stop_date::Union(Date, Nothing)
  dict::Dict  # Dict{String, Any}

  function TableOfContent(container::AbstractTableOfContent, start_date::Union(Date, Nothing),
      stop_date::Union(Date, Nothing), dict::Dict)
    table_of_content = new(container, start_date, stop_date, dict)
    finalizer(table_of_content, free!)
    return table_of_content
  end
end


type UnparsedSection <: Node
  short_title::String
  sortable_title::String

  UnparsedSection(short_title::String) = new(short_title, node_sortable_title(short_title))
end


function commonmark(article::Article, mode::String; depth::Int = 1)
  blocks = String[
    "#" ^ depth,
    " ",
    node_title(article),
    "\n\n",
  ]

  content = commonmark(article.dict["BLOC_TEXTUEL"]["CONTENU"])
  content = join(map(strip, split(content, '\n')), '\n')
  while searchindex(content, "\n\n\n") > 0
    content = replace(content, "\n\n\n", "\n\n")
  end
  push!(blocks, strip(content))
  push!(blocks, "\n")

  nota = get(article.dict, "NOTA", nothing)
  if nota !== nothing
    push!(blocks, "\n## Nota\n\n")
    content = commonmark(nota["CONTENU"])
    content = join(map(strip, split(content, '\n')), '\n')
    while searchindex(content, "\n\n\n") > 0
      content = replace(content, "\n\n\n", "\n\n")
    end
    push!(blocks, strip(content))
    push!(blocks, "\n")
  end

  return join(blocks)
end

function commonmark(non_article::NonArticle, mode::String; depth::Int = 1)
  blocks = String[]
  if !isempty(non_article.title)
    push!(blocks,
      "#" ^ depth,
      " ",
      non_article.title,
      "\n\n",
    )
  end
  content = commonmark(non_article.content)
  content = join(map(strip, split(content, '\n')), '\n')
  while searchindex(content, "\n\n\n") > 0
    content = replace(content, "\n\n\n", "\n\n")
  end
  push!(blocks, strip(content))
  push!(blocks, "\n\n")
  return join(blocks)
end

commonmark(section::Section, mode::String; depth::Int = 1) = string(
  "#" ^ depth,
  " ",
  node_title(section),
  "\n",
  commonmark_children(section, mode; depth = depth),
)

function commonmark(xhtml_element::XMLElement; depth::Int = 1)
  blocks = String[]
  for xhtml_node in child_nodes(xhtml_element)
    if is_textnode(xhtml_node)
      push!(blocks, content(xhtml_node))
    elseif is_elementnode(xhtml_node)
      xhtml_child = XMLElement(xhtml_node)
      child_name = name(xhtml_child)
      if child_name == "blockquote"
        push!(blocks, "\n")
        child_text = commonmark(xhtml_child, depth = depth)
        push!(blocks, join(map(line -> string("> ", strip(line)), split(strip(child_text), '\n')), '\n'))
        push!(blocks, "\n")
      elseif child_name == "br"
        push!(blocks, "\n\n")
      elseif child_name in ("abbr", "acronym", "code", "div", "font", "hr", "ol", "sub", "sup", "table", "u", "ul")
        push!(blocks, string(xhtml_child))
      elseif child_name in ("em", "i")
        content_commonmark = strip(commonmark(xhtml_child, depth = depth))
        if !isempty(content_commonmark)
          push!(blocks, "_")
          push!(blocks, content_commonmark)
          push!(blocks, "_")
        end
      elseif child_name in ("h1", "h2", "h3", "h4", "h5")
        content_commonmark = strip(commonmark(xhtml_child, depth = depth))
        if !isempty(content_commonmark)
          push!(blocks, "#" ^ (parseint(child_name[2]) + 1))
          push!(blocks, content_commonmark)
          push!(blocks, "\n\n")
        end
      elseif child_name == "NOTES"
        content_commonmark = strip(commonmark(xhtml_child, depth = depth))
        if !isempty(content_commonmark)
          push!(blocks, content_commonmark)
          push!(blocks, "\n\n")
        end
      elseif child_name == "p"
        push!(blocks, "\n\n")
        content_commonmark = rstrip(commonmark(xhtml_child, depth = depth))
        if !isempty(content_commonmark)
          push!(blocks, content_commonmark)
          push!(blocks, "\n\n")
        end
      elseif child_name in ("b", "strong")
        content_commonmark = strip(commonmark(xhtml_child, depth = depth))
        if !isempty(content_commonmark)
          push!(blocks, "**")
          push!(blocks, content_commonmark)
          push!(blocks, "**")
        end
      else
        error("Unexpected XHTML element $child_name in:\n$(string(xhtml_element)).")
      end
    end
  end
  return join(blocks)
end


commonmark_children(article::Article, mode::String; depth::Int = 1, link_prefix::String = "") = ""

function commonmark_children(section::Section, mode::String; depth::Int = 1, link_prefix::String = "")
  blocks = String[
    "\n",
  ]
  children_infos = [
    (node_sortable_title(child), name, child)
    for (name, child) in section.child_by_name
  ]
  sort!(children_infos)
  if mode == "single-page"
    for (index, (sortable_number, name, child)) in enumerate(children_infos)
      if index > 1
        push!(blocks, "\n")
      end
      push!(blocks, commonmark(child, mode; depth = depth + 1))
    end
  else
    indent = "  " ^ (depth - 1)
    for (sortable_number, name, child) in children_infos
      push!(blocks, "$(indent)- [$(node_short_title(child))]($link_prefix$name)\n")
      if mode == "deep"
        push!(blocks, commonmark_children(child, mode; depth = depth + 1, link_prefix = string(link_prefix, name, '/')))
      end
    end
  end
  return join(blocks)
end


free!(article::Article) = free!(article.dict)

function free!(dict::Dict)
  for (key, value) in dict
    if key == "CONTENU"
      # LighXML.jl needs explicit garbage collecting.
      dict[key] = nothing
      free(value)
    else
      free!(value)
    end
  end
end

function free!(document::Document)
  free!(document.texte_version)
  free!(document.textelr)
end

function free!(array::Array)
  for value in array
    free!(value)
  end
end

free!(table_of_content::TableOfContent) = free!(table_of_content.dict)

function free!(value)
end


function link_articles(articles_by_id)
  for (article_id, same_id_articles) in articles_by_id
    sort!(same_id_articles, by = article -> min_date(node_start_date(article), node_stop_date(article)))
  end
  for (article_id, same_id_articles) in articles_by_id
    for (article_index, article) in enumerate(same_id_articles)
      previous_article_with_same_id = article_index == 1 ? nothing : same_id_articles[article_index - 1]
      versions = article.dict["VERSIONS"]["VERSION"]
      version_index = findfirst(version -> version["LIEN_ART"]["@id"] == article_id, versions)
      if version_index > 1
        previous_version_article = nothing
        previous_version_article_index = 0
        previous_version_index = version_index - 1
        while previous_version_index > 0
          previous_version_id = versions[previous_version_index]["LIEN_ART"]["@id"]
          previous_version_articles = get(articles_by_id, previous_version_id, Article[])
          # Note: When previous_version_articles is empty, the article has an empty date interval. Skip it.
          if !isempty(previous_version_articles)
            previous_version_article_index = findlast(previous_version_articles) do previous_version_article
              return min_date(node_start_date(previous_version_article), node_stop_date(previous_version_article)) <
                min_date(node_start_date(article), node_stop_date(article))
            end
            if previous_version_article_index > 0
              previous_version_article = previous_version_articles[previous_version_article_index]
            end
            break
          end
          previous_version_index -= 1
        end
        previous_article = previous_article_with_same_id === nothing ?
          previous_version_article :
          previous_version_article !== nothing &&
              min_date(node_start_date(previous_article_with_same_id), node_stop_date(previous_article_with_same_id)) <
              min_date(node_start_date(previous_version_article), node_stop_date(previous_version_article)) ?
            previous_version_article :
            previous_article_with_same_id
      else
        previous_article = previous_article_with_same_id
      end
      if previous_article !== nothing
        if isnull(previous_article.next_version)
          previous_article.next_version = Nullable(article)
        else
          article_start_date = node_start_date(article)
          next_article = get(previous_article.next_version)
          next_article_start_date = node_start_date(next_article)
          warn(string(
            "Previous article ",
            node_id(previous_article),
            '@',
            node_start_date(previous_article),
            '-',
            node_stop_date(previous_article),
            " of ",
            article_id,
            '@',
            article_start_date,
            '-',
            node_stop_date(article),
            " already has a next version ",
            node_id(next_article),
            '@',
            next_article_start_date,
            '-',
            node_stop_date(next_article),
          ))
          if article_start_date < next_article_start_date
            previous_article.next_version = Nullable(article)
            article.next_version = Nullable(next_article)
          elseif article_start_date == next_article_start_date
            # The same article number appears twice at the same date. Don't even try to repair.
          else
            @assert isnull(next_article.next_version)
            next_article.next_version = Nullable(article)
          end
        end
      end
    end
  end
end


function load_article(dir::String, id::String)
  article_file_path = joinpath(dir, "article", id[1:4], id[5:8], id[9:10], id[11:12], id[13:14], id[15:16], id[17:18],
    id * ".xml")
  if !ispath(article_file_path)
    warn("Missing article file $article_file_path.")
    return @compat Dict{String, Any}()
  end
  article_xml_document = parse_file(article_file_path)
  return Convertible(parse_xml_element(root(article_xml_document))) |> pipe(
    element_to_article,
    require,
  ) |> to_value
  # free(article_xml_document)
end


max_date(left::Date, right::Date) = max(left, right)

max_date(left::Date, ::Nothing) = left

max_date(::Nothing, right::Date) = right

max_date(::Nothing, ::Nothing) = nothing


min_date(left::Date, right::Date) = min(left, right)

min_date(left::Date, ::Nothing) = left

min_date(::Nothing, right::Date) = right

min_date(::Nothing, ::Nothing) = nothing


function node_dir_name(simple_node::SimpleNode)
  dir_name = slugify(node_short_title(simple_node))
  if isempty(dir_name)
    dir_name = "sans-titre"
  end
  return dir_name
end

node_dir_name(section::Section) = section.dir_name

function node_dir_name(table_of_content::Document)
  dir_name = slugify(node_short_title(table_of_content))
  if isempty(dir_name)
    dir_name = "sans-titre"
  end
  return dir_name
end

function node_dir_name(table_of_content::TableOfContent)
  dir_name = slugify(node_number_and_simple_title(node_short_title(table_of_content))[2])
  if isempty(dir_name)
    dir_name = "sans-titre"
  end
  return dir_name
end


node_filename(article::Article) = string("article-", slugify(node_number(article)), ".md")

node_filename(non_article::NonArticle) = string(non_article.kind, ".md")

node_filename(node::Node) = node_dir_name(node) * ".md"


node_git_dir(article::Article) = node_git_dir(article.container)

node_git_dir(non_article::NonArticle) = node_git_dir(non_article.container)

node_git_dir(::RootNode) = ""

function node_git_dir(node::Node)
  container_git_dir = node_git_dir(node.container)
  dir_name = node_dir_name(node)
  return isempty(container_git_dir) ? dir_name : string(container_git_dir, '/', dir_name)
end


node_git_file_path(node::Node) = string(node_git_dir(node), '/', node_filename(node))


node_id(article::Article) = article.dict["META"]["META_COMMUN"]["ID"]

node_id(document::Document) = document.texte_version["META"]["META_COMMUN"]["ID"]

node_id(table_of_content::TableOfContent) = table_of_content.dict["ID"]

node_id(node_dict::Dict) = node_dict["META"]["META_COMMUN"]["ID"]


node_name(table_of_content::AbstractTableOfContent) = node_dir_name(table_of_content)

node_name(article::Article) = node_filename(article)

node_name(non_article::NonArticle) = node_filename(non_article)

node_name(simple_node::SimpleNode) = node_dir_name(simple_node)


node_number(table_of_content::AbstractTableOfContent) = node_number(node_short_title(table_of_content))

node_number(article::Article) = get(article.dict["META"]["META_SPEC"]["META_ARTICLE"], "NUM", "")

node_number(section::Section) = node_number(node_short_title(section))

node_number(short_title::String) = node_number_and_simple_title(short_title)[1]


node_number_and_simple_title(table_of_content::AbstractTableOfContent) = node_number_and_simple_title(node_short_title(
  table_of_content))

function node_number_and_simple_title(short_title::String)
  number_fragments = String[]
  simple_title_fragments = String[]
  for fragment in split(strip(short_title))
    fragment_lower = lowercase(fragment)
    if fragment_lower == "n°"
      continue
    end
    if startswith(fragment_lower, "n°")
      fragment = fragment[endof("n°"):end]
      fragment_lower = fragment_lower[endof("n°"):end]
    end
    slug = slugify(fragment_lower)
    if slug in ("chapitre", "livre", "paragraphe", "partie", "section", "sous-paragraphe", "sous-section",
        "sous-sous-paragraphe", "titre")
      push!(simple_title_fragments, fragment)
    elseif slug in ("annexe", "legislative", "preliminaire", "reglementaire", "rubrique", "sommaire", "suite",
        "tableau")
      # Partie législative, partie réglementaire, chapître préliminaire
      push!(number_fragments, fragment)
      push!(simple_title_fragments, fragment)
    elseif isdigit(fragment) || slug in ("ier", "unique") || ismatch(r"^[ivxlcdm]+$", fragment_lower) ||
        slug in keys(number_by_latin_extension) || slug in keys(number_by_slug) ||
        length(slug) <= 3 && all(letter -> 'a' <= letter <= 'z', slug) &&
          !(slug in ("de", "des", "du", "en", "la", "le", "les")) ||
        2 <= length(slug) <= 5 && 'a' <= slug[1] <= 'z' && isdigit(slug[2 : end]) ||
        3 <= length(slug) <= 6 && all(letter -> 'a' <= letter <= 'z', slug[1 : 2]) && isdigit(slug[3 : end])
      push!(number_fragments, fragment)
      push!(simple_title_fragments, fragment)
    elseif isempty(number_fragments)
      push!(simple_title_fragments, fragment)
    else
      break
    end
  end
  @assert !isempty(simple_title_fragments) "Empty simplification of title for: $title."
  return join(number_fragments, ' '), join(simple_title_fragments, ' ')
end


function node_short_title(document::Document)
  short_title = join(
    split(document.texte_version["META"]["META_SPEC"]["META_TEXTE_VERSION"]["TITRE"]), ' ')
  nor = get(document.texte_version["META"]["META_SPEC"]["META_TEXTE_CHRONICLE"], "NOR", "")
  if !isempty(nor)
    short_title = string(short_title, " (", nor, ")")
  end
  return short_title
end

node_short_title(non_article::NonArticle) = @compat Dict{String, String}(
  "notes" => "Nota",
  "signataires" => "Signataires",
  "visas" => "Visas",
)[non_article.kind]

node_short_title(section::Section) = section.short_title

node_short_title(section::UnparsedSection) = section.short_title

node_short_title(node::Node) = node_title(node)


node_sortable_title(article::Article) = node_sortable_title(node_number(article), node_short_title(article))

node_sortable_title(non_article::NonArticle) = @compat Dict{String, String}(
  "notes" => "9999998",
  "signataires" => "9999997",
  "visas" => "0000002",
)[non_article.kind]

node_sortable_title(section::Section) = section.sortable_title

node_sortable_title(simple_node::SimpleNode) = node_short_title(simple_node)

node_sortable_title(section::UnparsedSection) = section.sortable_title

node_sortable_title(table_of_content::AbstractTableOfContent) = node_sortable_title(node_short_title(table_of_content))

node_sortable_title(short_title::String) = isempty(short_title) ?
  "" :
  node_sortable_title(node_number_and_simple_title(short_title)...)

function node_sortable_title(number::String, simple_title::String)
  if isempty(number)
    return slugify(simple_title)
  end
  number_fragments = String[]
  slug = slugify(number)
  slug = replace(slug, "-a-l-article-", "-")
  for fragment in split(slug, '-')
    if isdigit(fragment)
      @assert length(fragment) <= 6 "Fragment is too long: $fragment"
      push!(number_fragments, string("000000", fragment, '0')[end - 6 : end])
    elseif fragment == "preliminaire"
      push!(number_fragments, "0000005")
    elseif fragment in ("ier", "legislative", "unique")
      push!(number_fragments, "0000010")
    elseif fragment in ("reglementaire", "suite")
      push!(number_fragments, "0000020")
    elseif fragment == "rubrique"
      push!(number_fragments, "7000000")
    elseif fragment == "sommaire"
      push!(number_fragments, "8000000")
    elseif fragment == "annexe"
      push!(number_fragments, "9000000")
    elseif fragment == "tableau"
      push!(number_fragments, "9500000")
    elseif ismatch(r"^[ivxlcdm]+$", fragment)
      value = 0
      for letter in fragment
        digit = [
          'i' => 1,
          'v' => 5,
          'x' => 10,
          'l' => 50,
          'c' => 100,
          'd' => 500,
          'm' => 1000,
        ][letter]
        if digit > value
          value = digit - value
        else
          value += digit
        end
      end
      @assert value < 1000000
      push!(number_fragments, string("000000", value, '0')[end - 6 : end])
    else
      number = get(number_by_latin_extension, fragment, "")
      if !isempty(number)
        push!(number_fragments, number)
      else
        number = get(number_by_slug, fragment, "")
        if !isempty(number)
          push!(number_fragments, number)
        elseif length(fragment) <= 3 && all(letter -> 'a' <= letter <= 'z', fragment) &&
            !(fragment in ("de", "des", "du", "en", "la", "le", "les"))
          push!(number_fragments, fragment)
        elseif 2 <= length(fragment) <= 5 && 'a' <= fragment[1] <= 'z' && isdigit(fragment[2 : end])
          push!(number_fragments, fragment[1 : 1])
          push!(number_fragments, string("000000", fragment[2 : end], '0')[end - 6 : end])
        elseif 3 <= length(fragment) <= 6 && all(letter -> 'a' <= letter <= 'z', fragment[1 : 2]) &&
            isdigit(fragment[3 : end])
          push!(number_fragments, fragment[1 : 2])
          push!(number_fragments, string("000000", fragment[3 : end], '0')[end - 6 : end])
        else
          push!(number_fragments, fragment)
        end
      end
    end
  end
  return join(number_fragments, '-')
end


node_start_date(article::Article) = article.start_date

node_start_date(document::Document) = get(document.texte_version["META"]["META_SPEC"]["META_TEXTE_VERSION"],
  "DATE_DEBUT", nothing)

node_start_date(table_of_content::TableOfContent) = table_of_content.start_date


function node_stop_date(node::Union(Article, TableOfContent))
  stop_date = node.stop_date
  if stop_date !== nothing && stop_date < node.start_date
    # May occur when ETAT = MODIFIE_MORT_NE.
    stop_date = node.start_date
  end
  return stop_date
end

node_stop_date(document::Document) = get(document.texte_version["META"]["META_SPEC"]["META_TEXTE_VERSION"],
  "DATE_FIN", nothing)


node_structure(table_of_content::Document) = table_of_content.textelr["STRUCT"]

node_structure(table_of_content::TableOfContent) = table_of_content.dict["STRUCTURE_TA"]


node_title(article::Article) = string("Article ", node_number(article))

node_title(simple_node::SimpleNode) = simple_node.title

node_title(section::Section) = section.title

node_title(document::Document) = join(
  split(document.texte_version["META"]["META_SPEC"]["META_TEXTE_VERSION"]["TITREFULL"]), ' ')

node_title(table_of_content::TableOfContent) = table_of_content.dict["TITRE_TA"]


parse_section_commonmark(repository::GitRepo, ::Nothing, section_short_title::String) = Section(section_short_title)

function parse_section_commonmark(repository::GitRepo, entry::GitTreeEntry, section_short_title::String)
  oid = Oid(entry)
  blob = lookup_blob(repository, oid)
  lines = split(text(blob), '\n')
  if !isempty(lines)
    title_line = lines[1]
    @assert startswith(title_line, "# ")
    section_title = title_line[3 : end]
    section = Section(isempty(section_short_title) ? section_title : section_short_title, section_title)
    if length(lines) >= 2
      @assert isempty(lines[2])
      for list_item_line in lines[3 : end]
        list_item_line_match = match(r"^- \[(?P<short_title>.+)\]\((?P<slug>.+)\)$", list_item_line)
        if list_item_line_match !== nothing
          section.child_by_name[list_item_line_match.captures[2]] = UnparsedSection(list_item_line_match.captures[1])
        end
      end
    end
    return section
  end
  return Section(section_short_title)
end


function parse_structure(table_of_content::AbstractTableOfContent, articles_by_id::Dict{String, Vector{Article}},
    changed_by_message_by_date::Dict{Date, Dict{String, Changed}}, dir::String)
  structure = node_structure(table_of_content)
  table_of_content_start_date = node_start_date(table_of_content)
  if table_of_content_start_date === nothing
    return
  end
  table_of_content_stop_date = node_stop_date(table_of_content)

  children = TableOfContent[]
  for lien_section_ta in get(structure, "LIEN_SECTION_TA", Dict{String, Any}[])
    lien_start_date = get(lien_section_ta, "@debut", nothing)
    if lien_start_date === nothing
      continue
    end
    if table_of_content_stop_date !== nothing && lien_start_date >= table_of_content_stop_date
      continue
    end
    lien_stop_date = get(lien_section_ta, "@fin", nothing)
    if lien_stop_date !== nothing && (lien_stop_date <= table_of_content_start_date ||
        lien_stop_date <= lien_start_date)
      continue
    end

    section_ta = nothing
    section_ta_file_path = joinpath(dir, "section_ta" * lien_section_ta["@url"])
    if !ispath(section_ta_file_path)
      warn("Missing SECTION_TA file $section_ta_file_path.")
      continue
    end
    try
      section_ta_xml_document = parse_file(section_ta_file_path)
      section_ta = Convertible(parse_xml_element(root(section_ta_xml_document))) |> pipe(
        element_to_section_ta,
        require,
      ) |> to_value
      # free(section_ta_xml_document)
    catch
      warn("An exception occured in file $section_ta_file_path.")
      rethrow()
    end
    child = TableOfContent(table_of_content, max_date(table_of_content_start_date, lien_start_date),
      min_date(table_of_content_stop_date, lien_stop_date), section_ta)
    # When the start date of the table of content is in conflict with the stop date of its previous version, consider
    # that the start date is right and correct the stop date.
    if !isempty(children)
      previous_child = children[end]
      if node_dir_name(previous_child) == node_dir_name(child) &&
          (previous_child.stop_date === nothing || previous_child.stop_date > child.start_date)
        previous_child.stop_date = child.start_date
      end
    end
    push!(children, child)
  end
  for child in children
    if child.stop_date !== nothing && child.start_date >= child.stop_date
      continue
    end
    parse_structure(child, articles_by_id, changed_by_message_by_date, dir)
  end

  child_articles = Article[]
  for lien_article in get(structure, "LIEN_ART", Dict{String, Any}[])
    lien_start_date = get(lien_article, "@debut", nothing)
    if lien_start_date === nothing
      continue
    end
    if table_of_content_stop_date !== nothing && lien_start_date >= table_of_content_stop_date
      continue
    end
    lien_stop_date = get(lien_article, "@fin", nothing)
    if lien_stop_date !== nothing && (lien_stop_date <= table_of_content_start_date ||
        lien_stop_date <= lien_start_date)
      continue
    end

    article_id = lien_article["@id"]
    article_dict = load_article(dir, article_id)
    if isempty(article_dict)
      continue
    end
    article = Article(table_of_content, max_date(table_of_content_start_date, lien_start_date),
      min_date(table_of_content_stop_date, lien_stop_date), article_dict)
    # When the start date of the article is in conflict with the stop date of its previous version, consider
    # that the start date is right and correct the stop date.
    if !isempty(child_articles)
      previous_article = child_articles[end]
      if node_filename(previous_article) == node_filename(article) &&
          (previous_article.stop_date === nothing || previous_article.stop_date > article.start_date)
        previous_article.stop_date = article.start_date
      end
    end
    push!(child_articles, article)
  end
  for article in child_articles
    if article.stop_date !== nothing && article.start_date >= article.stop_date
      continue
    end
    article_dict = article.dict
    article_id = article_dict["META"]["META_COMMUN"]["ID"]
    meta_article = article_dict["META"]["META_SPEC"]["META_ARTICLE"]
    same_id_articles = get!(articles_by_id, article_id) do
      return Article[]
    end
    push!(same_id_articles, article)
    try
      start_messages = String[]
      stop_messages = String[]
      for lien in get(article_dict["LIENS"], "LIEN", Dict{String, Any}[])
        if get(lien, "@datesignatexte", nothing) === nothing
          continue
        end

        if lien["@sens"] == "cible" && lien["@typelien"] in ("CREE", "DEPLACE", "MODIFIE") ||
            lien["@sens"] == "source" && lien["@typelien"] in ("MODIFICATION", "TRANSPOSITION")
          if meta_article["DATE_DEBUT"] <= lien["@datesignatexte"]
            info("Unexpected date $(lien["@datesignatexte"]) after DATE_DEBUT article $(meta_article["DATE_DEBUT"]) " *
              "in $article_id for: $lien. Ignoring link...")
          else
            message = split(lien["^text"], " - ")[1]
            if !(message in start_messages)
              push!(start_messages, message)
            end
          end
        elseif lien["@sens"] == "source" && lien["@typelien"] in ("ABROGATION", "DISJONCTION", "PEREMPTION",
            "SUBSTITUTION", "TRANSFERT") ||
            lien["@sens"] == "cible" && lien["@typelien"] in ("ABROGE", "DISJOINT", "PERIME", "TRANSFERE")
          stop_date = get(meta_article, "DATE_FIN", nothing)
          if stop_date !== nothing
            if stop_date <= lien["@datesignatexte"]
              info("Unexpected date $(lien["@datesignatexte"]) after DATE_FIN article $(stop_date) in " *
                "$article_id for: $lien. Ignoring link...")
            else
              message = split(lien["^text"], " - ")[1]
              if !(message in stop_messages)
                push!(stop_messages, message)
              end
            end
          end
        end
      end

      creation_date = node_start_date(article)
      @assert creation_date !== nothing
      if isempty(start_messages)
        push!(start_messages, "Modifications d'origine indéterminée")
      end
      changed_by_message = get!(changed_by_message_by_date, creation_date) do
        return @compat Dict{String, Changed}()
      end
      changed = get!(changed_by_message, join(start_messages, ", ", " et ")) do
        return Changed()
      end
      push!(changed.articles, article)

      deletion_date = node_stop_date(article)
      if deletion_date !== nothing
        if isempty(stop_messages)
          push!(stop_messages, "Suppressions d'origine indéterminée")
        end
        changed_by_message = get!(changed_by_message_by_date, deletion_date) do
          return @compat Dict{String, Changed}()
        end
        changed = get!(changed_by_message, join(stop_messages, ", ", " et ")) do
          return Changed()
        end
        push!(changed.deleted_articles, article)
      end
    catch
      warn("An exception occured in $(node_filename(article)) [$(get(meta_article, "ETAT", "inconnu"))]: $article_id.")
      rethrow()
    end
  end
end


function parse_xml_element(xml_element::XMLElement)
  element = @compat Dict{String, Any}()
  for attribute in attributes(xml_element)
    element[string('@', name(attribute))] = value(attribute)
  end
  previous = element
  for xml_node in child_nodes(xml_element)
    if is_textnode(xml_node)
      if previous === element
        element["^text"] = get(element, "^text", "") * content(xml_node)
      else
        previous["^tail"] = get(element, "^tail", "") * content(xml_node)
      end
    elseif is_elementnode(xml_node)
      xml_child = XMLElement(xml_node)
      child_name = name(xml_child)
      if child_name == "CONTENU"
        @assert !(child_name in element)
        element[child_name] = xml_child
      else
        child = parse_xml_element(xml_child)
        same_children = get!(element, child_name) do
          return Dict{String, Any}[]
        end
        push!(same_children, child)
        previous = child
      end
    end
  end
  return element
end


function slugify(string::String; separator::Char = '-', transform::Function = lowercase)
  simplified = replace(replace(string, "N°", "no "), "n°", "no ")
  return Slugify.slugify(simplified, separator = separator, transform = transform)
end
