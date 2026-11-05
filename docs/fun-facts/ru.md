# Fun facts

[English version](index.md)

Маленькие истории про слова, числа и соглашения, которые встречаются в проекте. У каждого факта — источник, по которому его можно проверить.

## 72: ширина строки коммита

Текст коммита под заголовком переносят примерно на 72 символа, а сам заголовок держат около 50. Число получено из терминала в 80 колонок: `git log` сдвигает текст на 4 пробела слева, ещё 4 оставляют справа для симметрии. Вторая причина — патчи по почте (`git format-patch`): запас нужен под несколько уровней `> ` во вложенных ответах. Заголовок длиннее 50 символов обрезают `git log --oneline`, `git shortlog`, `git rebase -i` и темы писем. Это соглашение, а не требование Git; автор сам называет 50 «не жёстким пределом».

Источник: [T. Pope, A Note About Git Commit Messages, 2008-04-19](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

## Slug: газетное слово в именах веток

Slug — короткое машинное имя из букв, цифр, подчёркиваний и дефисов, которое без проблем встаёт в URL или имя ветки. В `docs/AB11-autolink-urls` это `autolink-urls`. Слово из эпохи горячего набора: короткое имя статьи отливали крупно на одной свинцовой строке — slug, — и по ней опознавали набор статьи, пока его не поставили на полосу.

В веб слово принёс Django: его сделали в World Online, веб-редакции газеты из Лоуренса (Канзас), и поле для таких имён там называется `SlugField`. Документация Django начинает его описание словами «Slug is a newspaper term». Заодно так же устроены якоря на этом сайте: `#weighted-evaluation-method`.

Источники: [Django: SlugField](https://docs.djangoproject.com/en/stable/ref/models/fields/#slugfield), [Django: glossary, slug](https://docs.djangoproject.com/en/stable/glossary/#term-slug), [Django FAQ: history](https://docs.djangoproject.com/en/stable/faq/general/), [M. Perlman, Leading Questions, Columbia Journalism Review, 2010-11-01](https://www.cjr.org/language_corner/leading_questions.php).

## Ed25519: почему «Ed» и почему «25519»

«Ed» — это Эдвардс. В 2007 году математик Гарольд Эдвардс опубликовал новую нормальную форму эллиптических кривых, x² + y² = a² + a²x²y²: уравнение симметрично по x и y, и параметризующие функции ведут себя как синус и косинус для окружности. В том же году Дэниел Бернштейн и Таня Ланге вывели для таких кривых быстрые формулы сложения и удвоения, начав статью словами «Edwards recently introduced a new normal form», — так и появились «кривые Эдвардса». Их ценность для криптографии: одна и та же формула сложения работает и для удвоения, что затрудняет атаки по побочным каналам.

«25519» — это простое число 2²⁵⁵ − 19, над которым задана кривая. Подпись Ed25519 (Бернштейн, Дуиф, Ланге, Швабе, Ян, 2011) использует скрученную кривую Эдвардса, бирационально эквивалентную Curve25519. Именно таким ключом (`id_ed25519`) подписаны коммиты SignalLog.

Источники: [H. M. Edwards, A normal form for elliptic curves, Bulletin of the AMS 44 (2007), 393–422](https://doi.org/10.1090/S0273-0979-07-01153-6), [D. J. Bernstein, T. Lange, Faster addition and doubling on elliptic curves, IACR ePrint 2007/286](https://eprint.iacr.org/2007/286), [P. Schwabe et al., High-speed high-security signatures, CHES 2011 (слайды)](https://iacr.org/workshops/ches/ches2011/presentations/Session%203/CHES2011_Session3_2.pdf).
