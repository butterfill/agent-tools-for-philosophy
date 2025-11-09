# Test Cases for draft2keys Script

1.  **LaTeX Truncation Error:** A list of keys where the last key is often truncated by the faulty regex.
    \cite{steward:2009_animal, doggett:2012_questions}

1.b. **LaTeX Truncation Error with a single citation** \citep{smith:2012_friends}

2.  **LaTeX Greedy Capture Error:** A citation containing comments and newlines, which the original script will incorrectly capture and parse.
    \citep{malformed:key1, % a comment here
    malformed:key2}

3.  **Pandoc Multi-key Error:** A single bracketed Pandoc citation that contains multiple keys. The original script only finds the first one.
    [@pandoc:key1; see also @pandoc:key2]

4.  **Pandoc False Positive Error:** An email address that should not be identified as a citation key, but is.
    Contact the author at author@falsepositive.com for details.

# Correct ouput
The correct output for this file should be exactly:
```
steward:2009_animal
doggett:2012_questions
smith:2012_friends
pandoc:key1
pandoc:key2
```