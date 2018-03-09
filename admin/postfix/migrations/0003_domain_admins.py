# -*- coding: utf-8 -*-
# Generated by Django 1.10.3 on 2018-03-08 07:08
from __future__ import unicode_literals

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('postfix', '0002_auto_20161106_1144'),
    ]

    operations = [
        migrations.AddField(
            model_name='domain',
            name='admins',
            field=models.ManyToManyField(blank=True, to=settings.AUTH_USER_MODEL),
        ),
    ]