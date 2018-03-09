from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User
from django.forms import ModelForm, CharField, PasswordInput
from django import forms

from .models import Domain, EmailUser, Alias

import os, crypt, hashlib

class EmailUserForm(ModelForm):
    field_order = ['domain', 'username', 'password2', 'full_name', 'active',]
    password2 = CharField(widget=PasswordInput, label="Password", required=False)

    def clean(self):
        cleaned_data = super(EmailUserForm, self).clean()

        if not self.instance.id:
            domain = cleaned_data.get('domain')
            if domain and EmailUser.objects.filter(domain=domain).count() >= domain.max_accounts:
                raise forms.ValidationError('Reached the max number of accounts for this domain.')

    class Meta:
        model = EmailUser
        fields = ['domain', 'username', 'password2', 'full_name', 'active',]

class AliasForm(ModelForm):
    field_order = ['domain', 'source', 'destination', 'active',]

    class Meta:
        model = Alias
        fields = ['domain', 'source', 'destination', 'active',]

class DomainInline(admin.TabularInline):
    model = Domain.admins.through
    can_delete = False
    verbose_name = 'Domain'
    verbose_name_plural = 'Domains'

class DomainAwareModelAdmin(admin.ModelAdmin):
    def get_queryset(self, request):
        queryset = super(DomainAwareModelAdmin, self).get_queryset(request)
        if request.user.is_superuser:
            return queryset
        return queryset.filter(domain__admins=request.user)

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "domain" and not request.user.is_superuser:
            kwargs["queryset"] = Domain.objects.filter(admins=request.user)

        return super(DomainAwareModelAdmin, self).formfield_for_foreignkey(db_field, request, **kwargs)


class UserAdmin(BaseUserAdmin):
    inlines = (DomainInline, )
    exclude = ('admins', )

class DomainAdmin(admin.ModelAdmin):
    list_display = ('name', 'active',)
    list_editable = ('active',)
    ordering = ['name',]

class EmailUserAdmin(DomainAwareModelAdmin):
    form = EmailUserForm
    fields = ('domain', 'username', 'full_name', 'password2', 'active', )
    list_display = ('address', 'active',)
    list_editable = ('active',)
    ordering = ['domain', 'full_name', 'username',]

    def get_readonly_fields(self, request, obj=None):
        if obj:
            return self.readonly_fields + ('domain', 'username',)

        return self.readonly_fields

    def save_model(self, request, obj, form, change):
        password2 = form['password2'].value()

        if len(password2):
            salt = '$6$' + hashlib.sha512(os.urandom(16).encode('base_64')).hexdigest()[-16:]
            obj.password = crypt.crypt(password2, salt)

        obj.save()

class AliasAdmin(DomainAwareModelAdmin):
    form = AliasForm
    fields = ['domain', 'source', 'destination', 'active',]
    list_display = ('mapping', 'active',)
    list_editable = ('active',)
    ordering = ['domain', 'source',]

    def get_readonly_fields(self, request, obj=None):
        if obj:
            return self.readonly_fields + ('domain',)

        return self.readonly_fields


admin.site.unregister(User)
admin.site.register(User, UserAdmin)

admin.site.register(Domain, DomainAdmin)
admin.site.register(EmailUser, EmailUserAdmin)
admin.site.register(Alias, AliasAdmin)
