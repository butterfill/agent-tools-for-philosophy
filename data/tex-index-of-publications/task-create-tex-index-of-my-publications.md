
## Task

Create entries for each of my publications in `tex-index-of-publications.jsonl`. 

To illustrate, here is a sample line:

```json
{"key": "sinigaglia:2022_motor", "filenames": ["~/Documents/writing/intention\ motor\ representation\ 03\ joint\ action\ \(paper\ 3\)/submit\ 2021-12\ synthese\ pre-proof\ typos\ corrected/intention\ and\ motor\ representation\ in\ joint\ action.13.tex"]}
```

In this example, "key" is the BibTeX key from the list of `My Publications` below. "filenames" is the list of the files containing the source of the cannonical version of the publication. For journal articles and book chapters, there is usually only a single entry (do not include a mere template). For books, there will usually be one per chapter or one per section.

You can find a list of the BibTeX keys for my publications below, under `My Publications`.

Where there is already an entry for a BibTeX key in the index, you do not need to search for it.

Note that only some of my publications have .tex sources in this folder. You will not find all of them here. Find as many as you can.

You are currently in the folder "~/Documents/writing2/", so all filenames should start with that. (Some or all existing entries are from another folder, "~/Documents/writing/": please do not touch those entries (but you may let me know if you think one of them is wrong)!)

Prefer matches in immediate subfolders of this one wherever possible (ie. prefer files in `~/Documents/writing2/plural-aggregate-reductive/` over files in `~/Documents/writing2/plural-aggregate-reductive/submit revision 2 philosophical psychology special issue 2025-03-27/` providing you get a good match in the former.)

Git commit history may be helpful as you are typically looking for recently modified .tex files.


## Guidelines

Do not include .tex files which are merely wrappers: only include .txt files which have the content of the publication.

Use the `cite2bib` and `cite2md` cli commands explained below to check whether you have the correct .tex source. Verify each source carefully. 

It is often very difficult to identify the exact .tex source file. In general, I want one that is close to the published version. As in the example above, it is fine to have a version that includes minor corrections if that exists.


## Finding the fulltext of a cited source
You should be able to execute two shell commands:
  - cite2md - resolve citation/key to Markdown fulltext path
  - cite2bib - resolve citation/key to BibTeX entry

**Usage examples:**
- `cite2md -c "\citet{butterfill:2019_goals}"` — get full text from LaTeX citation
- `cite2md "butterfill:2019_goals"` — get full text from BibTeX key
- `cite2bib "\citet{butterfill:2019_goals}"` — get BibTeX entry from LaTeX citation  
- `cite2bib "butterfill:2019_goals"` — get BibTeX entry from BibTeX key

**Note:** Both tools accept either LaTeX-style citations (with `\citet{}`) or bare BibTeX keys. The tools are on your PATH, so no `./` prefix is needed.

Please check you can execute the shell commands `cite2md` and `cite2bib` to obtain info for the key `butterfill:2019_goals`.  Use their `--help` as needed.  **If you cannot execute these commands, stop immediately and report the error.**



## My Publications
sinigaglia:2022_motor
butterfill:2022_mechanistically
sacheli:2021_taking
sinigaglia:2021_seeing
sinigaglia:2020_motor_joint_experience
butterfill:2020_developing
low:2020_visiblya
sinigaglia:2020_motor
ooi:2020_interpersonal
zani:_mindreading
clarke:2019_joint
butterfill:2019_goals
michael:2018_seeing
butterfill:2017_coordinating
maymon:2017_poster
fizke:2017_are
dellagatta:2017_drawn
butterfill:2016_animal_mindreading
butterfill:2016_minimal
low:2016_cognitive
butterfill:2016_goal
hills:2015_foraging
butterfill:2015_gilbert
sinigaglia:2015_goal_ascription
butterfill:2015_planning
sinigaglia:2015_puzzle
butterfill:2015_perceiving
butterfill:2011_editorial
Butterfill:2012fk
butterfill:2012_interacting
butterfill:2012_intention
surtees_direct_2011
Butterfill:2011fk
butterfill_minimal
Robinson:2010uq
Knoblich:2010fk
vesper_minimal_2010
Apperly:2009ju
Butterfill:2001kc
Butterfill:2001fn
Butterfill:2007pe
Butterfill:2009vs
McCormack:2009nr
Nurmsoo:2010yi
chennells:2022_coordinated
michael:2022_intuitions
zani:2023_mindreading
szekely:2024_effortbased
butterfill:2024_machines
butterfill:2025_three
pascarelli:2024_principles
apperly:2025_mindreading
low:2023_view
butterfill:2020_blueprint
nurmsoo:2010_childrens
