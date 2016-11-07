from django.contrib import admin
from django.forms import ModelForm, CharField, PasswordInput

from .models import Domain, EmailUser

import os, crypt, hashlib

class EmailUserForm(ModelForm):
    password2 = CharField(widget=PasswordInput, label="Password", required=False)
    
    class Meta:
        model = EmailUser
        fields = ['domain', 'username', 'password2', 'full_name', 'active',]


class DomainAdmin(admin.ModelAdmin):
    list_display = ('name', 'active',)
    ordering = ['name',]

class EmailUserAdmin(admin.ModelAdmin):
    form = EmailUserForm
    list_display = ('domain', 'username', 'full_name', 'active',)
    ordering = ['domain', 'username', 'full_name',]

    def save_model(self, request, obj, form, change):
        password2 = form['password2'].value()

        if len(password2):
            salt = '$6$' + hashlib.sha512(os.urandom(16).encode('base_64')).hexdigest()[-16:]
            obj.password = crypt.crypt(password2, salt)

        obj.save()

admin.site.register(Domain, DomainAdmin)
admin.site.register(EmailUser, EmailUserAdmin)
