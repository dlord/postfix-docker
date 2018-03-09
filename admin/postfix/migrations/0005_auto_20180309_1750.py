# -*- coding: utf-8 -*-
# Generated by Django 1.10.3 on 2018-03-09 17:50
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('postfix', '0004_domain_max_accounts'),
    ]

    operations = [
        migrations.AlterModelOptions(
            name='alias',
            options={'verbose_name': 'Alias', 'verbose_name_plural': 'Aliases'},
        ),
        migrations.AddField(
            model_name='domain',
            name='user_quota_limit',
            field=models.CharField(default=b'2GB', max_length=255),
        ),
    ]
