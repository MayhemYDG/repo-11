from django.views.generic import TemplateView
from transactions .models import Transaction
from accounts .models import UserBankAccount
from django.shortcuts import render, redirect
import datetime
from django.utils import formats
from django.utils.timezone import utc
#
# class HomeView(TemplateView):
#     template_name = 'core/index.html'



def home(request):
    if request.user.is_authenticated:
        user_data = UserBankAccount.objects.filter(user= request.user)
        for i in user_data:
            print('check', i.balance)
        acc_no = user_data[0].account_no
        data = Transaction.objects.filter(account__account_no = acc_no)
        money_in = 0
        money_out = 0
        date_month_ago = datetime.datetime.utcnow().replace(tzinfo=utc) - datetime.timedelta(days=30)
        for transaction in data:
            if transaction.transaction_type == 1 and transaction.timestamp > date_month_ago:
                money_in += transaction.amount
            if transaction.transaction_type == 2 and transaction.timestamp > date_month_ago:
                money_out += transaction.amount


        data2 = Transaction.objects.filter(account__account_no=acc_no)
        for i in data2:
            print('all',i.timestamp)

        data2 = list(data2)
        data2 = data2[-5:]
        amount_deposit = []
        account_deposit = []
        timestamp_deposit = []
        amount_withdraw = []
        account_withdraw = []
        timestamp_withdraw = []
        deposit_data = []
        with_data = []
        for datnin in data2:
            if datnin.transaction_type == 1:
                # amount_deposit.append(datnin.amount)
                # print('amount_deposit', amount_deposit)
                # account_deposit.append(datnin.account)
                # timestamp_deposit.append(datnin.timestamp)
                # trans_data = {'amount': datnin.amount, 'account':datnin.account, 'timestamp': datnin.timestamp}
                deposit_data.append(datnin)
            elif datnin.transaction_type == 2:
                # amount_withdraw.append(datnin.amount)
                # account_withdraw.append(datnin.account)
                # timestamp_withdraw.append(datnin.timestamp)
                # trans_data = {'amount': amount_withdraw, 'account': account_withdraw, 'timestamp': timestamp_withdraw}
                with_data.append(datnin)
            else:
                pass
    else:
        return render(request, 'core/landing_page.html')
    return render(request, 'core/index.html',{'user_data':user_data, 'money_in':money_in, 'money_out':money_out, 'amount_deposit':amount_deposit,'account_deposit':account_deposit, 'timestamp_deposit': timestamp_deposit, 'amount_withdraw':amount_withdraw, 'account_withdraw':account_withdraw, 'timestamp_withdraw': timestamp_withdraw, 'with_data': with_data,'deposit_data': deposit_data})