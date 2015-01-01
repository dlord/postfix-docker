from flask import Flask
from flask.ext.sqlalchemy import SQLAlchemy
from flask.ext.admin import Admin
from flask.ext.admin.contrib.sqla import ModelView

from wtforms.fields import PasswordField

import os, crypt, hashlib

app = Flask(__name__)

# get config from environment.
db_user = os.getenv('db_user', 'root')

db_password = ''
if os.getenv('db_password'):
    db_password = ':' + os.getenv('db_password')

db_host = os.getenv('db_host', "postfixdb")
db_name = os.getenv('db_name', "postfix")

app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+mysqlconnector://' + db_user + db_password + '@' + db_host + '/' + db_name

db = SQLAlchemy(app)

class Domain(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), unique=True)
    active = db.Column(db.Boolean, default=True)

    def __str__(self):
        return self.name

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(255))
    email = db.Column(db.String(255), unique=True)
    password = db.Column(db.String(255))
    domain_id = db.Column(db.Integer, db.ForeignKey('domain.id'))
    domain = db.relationship('Domain', backref=db.backref('users', lazy='dynamic'))
    active = db.Column(db.Boolean, default=True)

class Alias(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    source = db.Column(db.String(255))
    destination = db.Column(db.String(255))
    domain_id = db.Column(db.Integer, db.ForeignKey('domain.id'))
    domain = db.relationship('Domain', backref=db.backref('aliases', lazy='dynamic'))
    active = db.Column(db.Boolean, default=True)

class DomainView(ModelView):
    column_list = ['name', 'active']
    column_filters = ['name']
    form_excluded_columns = ['aliases', 'users']

class UserView(ModelView):
    column_list = ['full_name','email', 'active']
    column_filters = ['full_name', 'email']
    column_searchable_list = ('full_name', 'email')
    form_excluded_columns = ['password']

    def scaffold_form(self):
        form_class = super(UserView, self).scaffold_form()
        form_class.password2 = PasswordField('New Password')
        return form_class

    def on_model_change(self, form, model):
        if len(model.password2):
            salt = '$6$' + os.urandom(64).encode('base_64')[-16:]
            model.password = crypt.crypt(form.password2.data, salt)

admin = Admin(app)
admin.add_view(DomainView(Domain, db.session))
admin.add_view(UserView(User, db.session))
admin.add_view(ModelView(Alias, db.session))

db.create_all()
