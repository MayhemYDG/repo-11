from django.db import models
from django.conf import settings
from .constants import TRANSACTION_TYPE_CHOICES
from accounts.models import UserBankAccount
from accounts.models import User
upload_to = settings.MEDIA_ROOT


class Transaction(models.Model):
    account = models.ForeignKey(
        UserBankAccount,
        related_name='transactions',
        on_delete=models.CASCADE,
    )
    amount = models.DecimalField(
        decimal_places=2,
        max_digits=12
    )
    balance_after_transaction = models.DecimalField(
        decimal_places=2,
        max_digits=12
    )
    transaction_type = models.PositiveSmallIntegerField(
        choices=TRANSACTION_TYPE_CHOICES
    )
    timestamp = models.DateTimeField(auto_now_add=True)

    description = models.TextField(null=True)

    def __str__(self):
        return str(self.account.account_no)

    class Meta:
        ordering = ['timestamp']

class Statement(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    date = models.DateTimeField(null = True)
    statements_pdf = models.FileField(upload_to=upload_to)

    def __str__(self):
        return str(self.user.email)

    def format_date(self):
        return self.date.strftime('%b, %Y')