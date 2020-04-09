const multipart = require('connect-multiparty');
const bodyParser = require('body-parser');
const session = require('cookie-session');
const engines = require('consolidate');
const express = require('express');
const fs = require('fs');

const { Client, InvalidRequest, Unauthorized } = require('base-api-io');


// APP SETUP
// =============================================================================

const upload = multipart();
const app = express();

app.engine('ejs', engines.qejs);

app.set('view engine', 'ejs');

app.use(bodyParser.urlencoded({ extended: true }));

app.use(session({
  name: 'session',
  secret: 'secret',
  cookie: {
    secure: false,
    httpOnly: true,
  },
}));

app.use((req, res, next) => {
  res.locals.loggedIn = !!req.session.userId;
  next();
});

const getErrorMessage = (error) => {
  if (error instanceof InvalidRequest) {
    return `Invalid request: ${error.data.error}`;
  } if (error instanceof Unauthorized) {
    return 'Unauthorized!';
  }
  return `Something went wrong: ${error.toString()}`;
};

// CREATE A CLIENT
// =============================================================================

const client = new Client('4dcfbd28-ae85-4370-9529-45cced846cba');

// REGISTER
// =============================================================================

app.get('/register', async (req, res) => {
  if (res.locals.loggedIn) {
    res.redirect('/');
  } else {
    res.render('register', {
      confirmation: '',
      custom_data: '',
      password: '',
      error: null,
      email: '',
    });
  }
});

app.post('/register', async (req, res) => {
  if (res.locals.loggedIn) {
    res.redirect('/');
  } else {
    try {
      const user = await client.users.create(
        req.body.email,
        req.body.password,
        req.body.confirmation,
        req.body.custom_data && JSON.parse(req.body.custom_data),
      );

      req.session.userId = user.id;
      res.redirect(`/users/${user.id}`);
    } catch (error) {
      res.render('register', {
        error: getErrorMessage(error),
        confirmation: req.body.confirmation,
        custom_data: req.body.custom_data,
        password: req.body.password,
        email: req.body.email,
      });
    }
  }
});

// LOGIN
// =============================================================================

app.get('/login', async (req, res) => {
  if (res.locals.loggedIn) {
    res.redirect('/');
  } else {
    res.render('login', {
      password: '',
      error: null,
      email: '',
    });
  }
});

app.post('/login', async (req, res) => {
  if (res.locals.loggedIn) {
    res.redirect('/');
  } else {
    try {
      const user = await client.sessions.authenticate(req.body.email, req.body.password);

      req.session.userId = user.id;
      res.redirect(`/users/${user.id}`);
    } catch (error) {
      res.render('login', {
        error: getErrorMessage(error),
        password: req.body.password,
        email: req.body.email,
      });
    }
  }
});

// LOGOUT
// =============================================================================

app.get('/logout', async (req, res) => {
  req.session.userId = null;
  res.redirect('/');
});

// USER
// =============================================================================

app.get('/users', async (req, res) => {
  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.users.list(page);

  res.render('users', { data, page });
});

app.get('/users/:id', async (req, res) => {
  try {
    const user = await client.users.get(req.params.id);

    res.render('user', { user });
  } catch (error) {
    res.redirect('/users');
  }
});

app.get('/users/:id/update', async (req, res) => {
  let error = null;
  let user = {
    custom_data: '',
    email: '',
    id: '',
  };

  try {
    user = await client.users.get(req.params.id);
  } catch (rawError) {
    error = getErrorMessage(rawError);
  }

  res.render('update-user', {
    custom_data: user.custom_data,
    email: user.email,
    id: req.params.id,
    error,
  });
});

app.post('/users/:id', async (req, res) => {
  let customData = '';

  try {
    const user = await client.users.get(req.params.id);

    customData = (req.body.custom_data.trim() === '') ? null : JSON.parse(req.body.custom_data);

    await client.users.update(
      user.id,
      req.body.email,
      customData,
    );

    res.redirect(`/users/${user.id}`);
  } catch (error) {
    res.render('update-user', {
      error: getErrorMessage(error),
      custom_data: req.body.custom_data,
      email: req.body.email,
      id: req.params.id,
    });
  }
});

app.post('/users/:id/delete', async (req, res) => {
  try {
    await client.users.delete(req.params.id);

    if (req.params.id === req.session.userId) {
      req.session.userId = null;
    }

    res.redirect('/users');
  } catch (error) {
    res.redirect('/users');
  }
});

// SEND EMAIL
// =============================================================================

app.get('/emails', async (req, res) => {
  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.emails.list(page);

  res.render('emails', { data, page });
});

app.get('/send-email', async (req, res) => {
  res.render('send-email', {
    success: null,
    error: null,
    subject: '',
    email: '',
    from: '',
    html: '',
    text: '',
    to: '',
  });
});

app.post('/send-email', async (req, res) => {
  let success = null;
  let error = null;

  try {
    await client.emails.send(
      req.body.subject,
      req.body.from,
      req.body.to,
      null,
      req.body.html,
      req.body.text,
    );

    success = true;
  } catch (rawError) {
    error = getErrorMessage(rawError);
  }

  res.render('send-email', {
    subject: req.body.subject,
    from: req.body.from,
    html: req.body.html,
    text: req.body.text,
    to: req.body.to,
    success,
    error,
  });
});

// UPLOAD FILE
// =============================================================================

app.get('/upload-file', async (req, res) => {
  res.render('upload-file', { error: null });
});

app.post('/upload-file', upload, async (req, res) => {
  try {
    const file = await client.files.create({
      content_type: req.files.file.type,
      file: req.files.file.path,
    });

    fs.unlink(req.files.file.path, () => {});

    res.redirect(`/files/${file.id}`);
  } catch (error) {
    console.log(error)
    res.render('upload-file', {
      error: getErrorMessage(error),
    });
  }
});

// FILE
// =============================================================================

app.get('/files', async (req, res) => {
  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.files.list(page);

  res.render('files', { data, page });
});

app.get('/files/:id', async (req, res) => {
  try {
    const file = await client.files.get(req.params.id);

    res.render('file', { file });
  } catch (error) {
    res.redirect('/files');
  }
});

app.post('/files/:id/delete', async (req, res) => {
  try {
    await client.files.delete(req.params.id);

    res.redirect('/files');
  } catch (error) {
    res.redirect('/files');
  }
});

// UPLOAD IMAGE
// =============================================================================

app.get('/images', async (req, res) => {
  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.images.list(page);

  res.render('images', { data, page });
});

app.get('/upload-image', async (req, res) => {
  res.render('upload-image', { error: null });
});

app.post('/upload-image', upload, async (req, res) => {
  try {
    const image = await client.images.create({
      content_type: req.files.image.type,
      file: req.files.image.path,
    });

    fs.unlink(req.files.image.path, () => {});

    res.redirect(`/images/${image.id}`);
  } catch (error) {
    res.render('upload-image', {
      error: getErrorMessage(error),
    });
  }
});

// IMAGE
// =============================================================================

app.get('/images/:id', async (req, res) => {
  try {
    const image = await client.images.get(req.params.id);

    res.render('image', { image });
  } catch (error) {
    res.redirect('/images');
  }
});

app.post('/images/:id/delete', async (req, res) => {
  try {
    await client.images.delete(req.params.id);

    res.redirect('/images');
  } catch (error) {
    res.redirect('/images');
  }
});

// HOME
// =============================================================================

app.get('/', async (req, res) => {
  res.render('index');
});

// MAILING LISTS
// =============================================================================

app.get('/mailing-lists', async (req, res) => {
  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.mailingLists.list(page);

  res.render('mailing-lists', { data, page });
});

app.get('/mailing-lists/:id', async (req, res) => {
  try {
    const list = await client.mailingLists.get(req.params.id);

    res.render('mailing-list', { list, client });
  } catch (error) {
    res.redirect('/mailing-lists');
  }
});

app.post('/mailing-lists/:id/subscribe', async (req, res) => {
  try {
    await client.mailingLists.subscribe(req.params.id, req.body.email);

    res.redirect(`/mailing-lists/${req.params.id}`);
  } catch (error) {
    res.redirect('/mailing-lists');
  }
});

app.post('/mailing-lists/:id/unsubscribe', async (req, res) => {
  try {
    await client.mailingLists.unsubscribe(req.params.id, req.body.email);

    res.redirect(`/mailing-lists/${req.params.id}`);
  } catch (error) {
    res.redirect('/mailing-lists');
  }
});

app.post('/mailing-lists/:id/send', async (req, res) => {
  try {
    await client.mailingLists.send(
      req.params.id,
      req.body.subject,
      req.body.from,
      req.body.html,
      req.body.text,
    );

    res.redirect(`/mailing-lists/${req.params.id}`);
  } catch (error) {
    res.redirect('/mailing-lists');
  }
});

// FORMS
// =============================================================================

app.get('/forms', async (req, res) => {
  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.forms.list(page);

  res.render('forms', { data, page });
});

app.get('/forms/create', async (req, res) => {
  res.render('form-create', { error: null });
});

app.post('/forms/create', async (req, res) => {
  try {
    const form = await client.forms.create(req.body.name);

    res.redirect(`/forms/${form.id}`);
  } catch (error) {
    res.render('form-create', {
      error: getErrorMessage(error),
    });
  }
});

app.get('/forms/:id', async (req, res) => {
  try {
    const form = await client.forms.get(req.params.id);

    res.render('form', { form });
  } catch (error) {
    res.redirect('/forms');
  }
});

app.post('/forms/:id/delete', async (req, res) => {
  try {
    await client.forms.delete(req.params.id);

    res.redirect('/forms');
  } catch (error) {
    res.redirect('/forms');
  }
});

app.get('/forms/:id/submit', async (req, res) => {
  const form = await client.forms.get(req.params.id);

  res.render('form-submit', { error: null, form: form });
});

app.post('/forms/:id/submit', async (req, res) => {
  try {
    const form = await client.forms.get(req.params.id);

    const submission = await client.forms.submit(form.id, { data: req.body.data });

    res.redirect(`/forms/${form.id}/submissions/${submission.id}`);
  } catch (error) {
    res.render('form-submit', {
      error: getErrorMessage(error),
    });
  }
});

app.get('/forms/:id/submissions', async (req, res) => {
  const form = await client.forms.get(req.params.id);

  const page = req.query.page ? parseInt(req.query.page, 10) : 1;

  const data = await client.forms.submissions(req.params.id, page);

  res.render('form-submissions', { data, page , form});
});

app.get('/forms/:id/submissions/:submissionId', async (req, res) => {
  const form = await client.forms.get(req.params.id);
  const submission = await client.forms.getSubmission(req.params.id, req.params.submissionId);

  res.render('form-submission', { submission, form});
});

app.post('/forms/:id/submissions/:submissionId/delete', async (req, res) => {
  const form = await client.forms.get(req.params.id);

  await client.forms.deleteSubmission(req.params.id, req.params.submissionId);

  res.redirect(`/forms/${form.id}/submissions`)
});
app.listen(3000);
