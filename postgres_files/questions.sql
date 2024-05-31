1. При использовании DBeaver возникает ошибка при попытке запуска COPY FROM STDIN;
SQL Error [57014]: ERROR: COPY from stdin failed: COPY commands are only supported using the CopyManager API.
  Where: COPY genre, line 1
  ERROR: COPY from stdin failed: COPY commands are only supported using the CopyManager API.
  Where: COPY genre, line 1
  ERROR: COPY from stdin failed: COPY commands are only supported using the CopyManager API.
  Where: COPY genre, line 1

В результате заменил ввод данных с COPY на INSERT

2. Почему не ставить у всех объектов при сгать оздании IF NOT EXISTS чтобы избегать ошибок при перезапуске скрипта?

3. В скрипте который скачан с ЛК Специалист по ссылке "Ссылка на скрипт создания БД", которая далее ведет на Я.Диск и скачивается файл BooxStoreX.sql отсутвуют данные для таблиц схемы shop (order_main и т.д)