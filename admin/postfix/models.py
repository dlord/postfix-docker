from django.db import models


class Domain(models.Model):
    name = models.CharField(max_length=255, unique=True)
    active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class EmailUser(models.Model):
    full_name = models.CharField(max_length=255)
    username = models.CharField(max_length=255, db_index=True)
    password = models.CharField(max_length=255)
    domain = models.ForeignKey(Domain)
    active = models.BooleanField(default=True)

    def __str__(self):
        return self.full_name

    class Meta:
        unique_together = ('username', 'domain')


class Alias(models.Model):
    source = models.CharField(max_length=255)
    destination = models.CharField(max_length=255)
    domain = models.ForeignKey(Domain)
    active = models.BooleanField(default=True)

    def __str__(self):
        return self.source + " = " + self.destination

    class Meta:
        unique_together = ('source', 'destination', 'domain')
