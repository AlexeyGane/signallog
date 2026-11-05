# Fun facts

[Русская версия](ru.md)

Short stories behind the words, numbers and conventions that turn up in this project. Each fact links to a source that can be checked.

## 72: the width of a commit message

The body of a commit message is wrapped at about 72 characters, and the subject line is kept to about 50. The number comes from an 80-column terminal: `git log` indents the message by 4 spaces on the left, and another 4 are left on the right for symmetry. The second reason is patches sent by email (`git format-patch`): the margin leaves room for several levels of `> ` in nested replies. A subject longer than 50 characters gets cut off in `git log --oneline`, `git shortlog`, `git rebase -i` and email subjects. This is a convention, not a rule enforced by Git; the author calls 50 "not a hard maximum".

Source: [T. Pope, A Note About Git Commit Messages, 2008-04-19](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

## Slug: a newspaper word in branch names

A slug is a short machine-friendly name made of letters, digits, underscores and hyphens, which fits into a URL or a branch name as it is. In `docs/AB11-autolink-urls`, the slug is `autolink-urls`. The word dates from hot-metal typesetting: the short name of a story was cast in large type on a single line of lead, the slug, and that line identified the story's type until it was placed on a page.

The word came to the web with Django. Django was built at World Online, the web operation of a newspaper in Lawrence, Kansas, and its field for such names is called `SlugField`. The Django documentation opens its description with "Slug is a newspaper term". The anchors on this site are slugs too: `#weighted-evaluation-method`.

Sources: [Django: SlugField](https://docs.djangoproject.com/en/stable/ref/models/fields/#slugfield), [Django: glossary, slug](https://docs.djangoproject.com/en/stable/glossary/#term-slug), [Django FAQ: history](https://docs.djangoproject.com/en/stable/faq/general/), [M. Perlman, Leading Questions, Columbia Journalism Review, 2010-11-01](https://www.cjr.org/language_corner/leading_questions.php).

## Ed25519: why "Ed" and why "25519"

"Ed" stands for Edwards. In 2007 the mathematician Harold Edwards published a new normal form for elliptic curves, x² + y² = a² + a²x²y². The equation is symmetric in x and y, and the functions that parametrise it behave like sine and cosine on a circle. In the same year Daniel Bernstein and Tanja Lange derived fast addition and doubling formulas for such curves, opening their paper with "Edwards recently introduced a new normal form"; this is how "Edwards curves" got their name. What makes them useful in cryptography is that one addition formula also handles doubling, which makes side-channel attacks harder.

"25519" is the prime 2²⁵⁵ − 19 over which the curve is defined. The Ed25519 signature scheme (Bernstein, Duif, Lange, Schwabe, Yang, 2011) uses a twisted Edwards curve that is birationally equivalent to Curve25519. The commits of SignalLog are signed with a key of this type (`id_ed25519`).

Sources: [H. M. Edwards, A normal form for elliptic curves, Bulletin of the AMS 44 (2007), 393–422](https://doi.org/10.1090/S0273-0979-07-01153-6), [D. J. Bernstein, T. Lange, Faster addition and doubling on elliptic curves, IACR ePrint 2007/286](https://eprint.iacr.org/2007/286), [P. Schwabe et al., High-speed high-security signatures, CHES 2011 (slides)](https://iacr.org/workshops/ches/ches2011/presentations/Session%203/CHES2011_Session3_2.pdf).
