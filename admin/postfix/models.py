from django.db import models
from django.contrib.auth.models import User


class Domain(models.Model):
    name = models.CharField(max_length=255, unique=True)
    active = models.BooleanField(default=True)
    admins = models.ManyToManyField(User, blank=True)
    max_accounts = models.IntegerField(default=5)

    def __str__(self):
        return self.name


class EmailUser(models.Model):
    full_name = models.CharField(max_length=255)
    username = models.CharField(max_length=255, db_index=True)
    password = models.CharField(max_length=255)
    domain = models.ForeignKey(Domain)
    active = models.BooleanField(default=True)

    def __str__(self):
        return self.address()

    def address(self):
        return '{} <{}@{}>'.format(self.full_name, self.username, self.domain)
    address.short_description = 'Email Address'

    class Meta:
        unique_together = ('username', 'domain')


class Alias(models.Model):
    source = models.CharField(max_length=255)
    destination = models.CharField(max_length=255)
    domain = models.ForeignKey(Domain)
    active = models.BooleanField(default=True)

    def __str__(self):
        return self.mapping()

    def mapping(self):
        return self.source + " => " + self.destination

    class Meta:
        unique_together = ('source', 'destination', 'domain')
        verbose_name = 'Alias'
        verbose_name_plural = 'Aliases'
