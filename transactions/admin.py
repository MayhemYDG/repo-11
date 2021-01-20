from django.contrib import admin
from import_export.admin import ImportExportModelAdmin
from transactions.models import Transaction, Statement


@admin.register(Transaction)
class TransactionAdmin(ImportExportModelAdmin):
    pass

admin.site.register(Statement)
