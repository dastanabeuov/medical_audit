# Папка для протоколов МЗ РК

Поместите сюда файлы протоколов в форматах:
- PDF
- DOCX
- XLSX
- TXT

После добавления файлов выполните команду:
```bash
rails knowledge_base:import_protocols
```

Для полного обновления базы (удаление старых + импорт новых):
```bash
rails knowledge_base:refresh_all
```