# -*- coding: utf-8 -*-
# Generated by Django 1.10.3 on 2018-03-08 15:19
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('postfix', '0003_domain_admins'),
    ]

    operations = [
        migrations.AddField(
            model_name='domain',
            name='max_accounts',
            field=models.IntegerField(default=5),
        ),
    ]