from django.urls import path

from .views import DepositMoneyView, WithdrawMoneyView, TransactionRepostView, pdfunc, statements


app_name = 'transactions'


urlpatterns = [
    path("deposit/", DepositMoneyView.as_view(), name="deposit_money"),
    path("report/", TransactionRepostView.as_view(), name="transaction_report"),
    path("withdraw/", WithdrawMoneyView.as_view(), name="withdraw_money"),
    path("statements/", statements, name="statements"),
    path("pdf_template/", pdfunc)
]
