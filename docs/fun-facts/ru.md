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

## Fitness function: из генетических алгоритмов в архитектуру

В эволюционных вычислениях программа ищет решение так, как действует естественный отбор. Генетические алгоритмы, которые исследовал Джон Холланд (1973, 1975), работают поколениями: набор кандидатов случайно варьируется, каждого оценивает fitness function («функция приспособленности») — насколько он близок к цели, — и в следующее поколение проходят лучшие. Именно эта функция определяет, что считать успехом; её выбирает тот, кто ставит задачу.

Нил Форд, Ребекка Парсонс и Патрик Куа перенесли понятие в архитектуру ПО: «We borrow a concept from evolutionary computing called fitness functions». Архитектурная fitness function — объективная, по возможности автоматическая проверка архитектурного свойства, которая выполняется постоянно; авторы сравнивают её с модульным тестом, только для архитектуры. В SignalLog такая проверка — проект-зонд с вызовами запрещённых API: CI убеждается, что каждая такая строка даёт ошибку компиляции.

Источники: N. Ford, R. Parsons, P. Kua. *Building Evolutionary Architectures*. O'Reilly, 2017, ISBN 978-1-491-98636-3; 2-е изд., 2022, ISBN 978-1-492-09754-9 ([глава 2, Fitness Functions](https://oreilly.com/library/view/building-evolutionary-architectures/9781492097532/ch02.html)); [MathWorld: Genetic Algorithm](https://mathworld.wolfram.com/GeneticAlgorithm.html). Источники остальных понятий проекта — на странице [Concepts and their sources](../standards/concepts-and-sources.md).

## tj-actions/changed-files: как переставленный тег раздал секреты

tj-actions/changed-files — действие (action) для GitHub Actions, которое сообщает, какие файлы изменились в коммите или pull request; от него зависели десятки тысяч репозиториев. 14 марта 2025 года исследователи StepSecurity заметили, что его код подменён: злоумышленник переставил git-теги версий на свой коммит. Каждый workflow, подключавший действие по тегу, при следующем запуске получил чужой код, который выгружал память раннера и печатал найденные секреты прямо в журнал сборки. У публичных репозиториев эти журналы может прочитать кто угодно. Секреты утекли из 218 репозиториев (первые оценки говорили о 23 000), в основном короткоживущие `GITHUB_TOKEN`, но и несколько десятков ключей к DockerHub, npm и AWS.

Цепочка началась задолго до этого. В ноябре–декабре 2024 года через уязвимый workflow `pull_request_target` проекта SpotBugs у мейнтейнера украли персональный токен. 11 марта 2025 года с его помощью добрались до токена мейнтейнера reviewdog и подменили тег `v1` у reviewdog/action-setup. Через зависимое действие tj-actions/eslint-changed-files утёк токен бота tj-actions — и им уже переставили теги changed-files. По данным Unit 42, первой целью был открытый проект Coinbase agentkit; Coinbase атаку отбила. Уязвимости получили номера CVE-2025-30066 и CVE-2025-30154, CISA внесла первую в каталог эксплуатируемых уязвимостей 18 марта 2025 года.

Мораль для SignalLog: тег — это подвижная ссылка, которую владелец (или тот, кто украл его токен) может переставить на любой коммит. Полный хеш коммита вычисляется из содержимого, поэтому его нельзя перенаправить на другой код. Поэтому все сторонние действия в наших workflow указаны полным SHA, а обновления версий приходят от Dependabot отдельными pull request и проходят ревью.

Источники: [CISA, Supply Chain Compromise of Third-Party GitHub Action, CVE-2025-30066, 2025-03-18](https://cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-github-action-cve-2025-30066); [GitHub Advisory GHSA-mrrh-fwg8-r2c3](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3); [The Hacker News, 2025-03-23](https://thehackernews.com/2025/03/github-supply-chain-breach-coinbase.html); [Infosecurity Magazine: Tj-actions Supply Chain Attack Traced Back to Single GitHub Token Compromise](https://www.infosecurity-magazine.com/news/tj-actions-supply-chain-attack/).
