# PostProcess_Beta

The purpose of this stored procedure is to modify story data via post save script. The post save script is executed as a story is saved in the Edit Interface for NEWSCYCLE Digital. Note, this 90% of this script WAS NOT written by me. This repo is just to demonstrate a modification I wrote for it. The modification I wrote for this reformats the dateline for an article. Unfortunately, this update wasn't as simple as updating a value in a database field since the dateline value for Digital First Media (DFM) sites are not stored in their own field. The dateline is part of the first paragraph for each article like so:

new york - Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Furthermore, this script reformats the dateline by taking the text in the first paragraph, storying the text in a table created on the fly, and doing a regex against the paragraph text for the date line (the Regex is told to stop at the em dash after the dateline). Lastly, everything before the dateline value is replaced with it's uppercase version like so:

new york - Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
proident, sunt in culpa qui officia deserunt mollit anim id est laborum.


The lines I added for this project are as followed:


- lines 36-37

- lines 40-43

- lines 45-49

- lines 51-52

- lines 78-84

- lines 86-93

- lines 96-103

- lines 105-108


