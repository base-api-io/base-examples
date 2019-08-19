const bodyParser = require('body-parser');
const session = require('cookie-session');
const express = require('express');
const multer  = require('multer')
const fs = require('fs')

const storage = multer.diskStorage({
  destination: 'uploads/',
  filename: function (req, file, cb) {
    cb(null, file.originalname)
  }
})

const upload = multer({
  storage: storage,
  limits: {
    fieldNameSize: 100,
    fieldSize: 1000000,
    fileSize: 1000000
  }
});

const app = express();

const { Client } = require('base-api-io');

const client = new Client.Client('4dcfbd28-ae85-4370-9529-45cced846cba');

app.set('view engine', 'pug');

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
  if (error instanceof Client.InvalidRequest) {
    return `Invalid request: ${error.data.error}`;
  } if (error instanceof Client.Unauthorized) {
    return 'Unauthorized!';
  } else {
    return 'Something went wrong!';
  }
};

// REGISTER
// =============================================================================

app.get('/register', async (req, res) => {
  if (res.locals.loggedIn) {
    res.redirect('/');
  } else {
    res.render('register', {});
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
      );

      req.session.userId = user.id;
      res.redirect(`/users/${user.id}`);
    } catch (error) {
      res.render('register', {
        error: getErrorMessage(error),
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
    res.render('login');
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

app.get('/users/:id', async (req, res) => {
  try {
    const user = await client.users.get(req.params.id);

    res.render('user', { user });
  } catch (error) {
    res.render('not-found');
  }
});

app.post('/users/:id/delete', async (req, res) => {
  try {
    const user = await client.users.delete(req.params.id);

    if (req.params.id == req.session.userId) {
      req.session.userId = null
    }

    res.redirect('/')
  } catch (error) {
    res.render('not-found');
  }
});

// SEND EMAIL
// =============================================================================

app.get('/send-email', async (req, res) => {
  res.render('send-email');
});

app.post('/send-email', async (req, res) => {
  try {
    await client.emails.send(
      req.body.subject,
      req.body.from,
      req.body.to,
      req.body.html,
      req.body.text,
    );

    res.render('send-email', { success: true });
  } catch (error) {
    res.render('send-email', {
      error: getErrorMessage(error),
      subject: req.body.subject,
      from: req.body.from,
      html: req.body.html,
      text: req.body.text,
      to: req.body.to,
    });
  }
});

// UPLOAD FILE
// =============================================================================

app.get('/upload-file', async (req, res) => {
  res.render('upload-file');
});

app.post('/upload-file', upload.single('file'), async (req, res) => {
  try {
    const file = await client.files.create({
      content_type: req.file.mimetype,
      file: req.file.path
    });

    fs.unlink(req.file.path)

    res.redirect(`/files/${file.id}`);
  } catch (error) {
    res.render('upload-file', {
      error: getErrorMessage(error),
    });
  }
});

// FILE
// =============================================================================

app.get('/files/:id', async (req, res) => {
  try {
    const file = await client.files.get(req.params.id);

    res.render('file', { file });
  } catch (error) {
    res.render('not-found');
  }
});

app.post('/files/:id/delete', async (req, res) => {
  try {
    await client.files.delete(req.params.id);

    res.redirect('/')
  } catch (error) {
    res.render('not-found');
  }
});

// UPLOAD IMAGE
// =============================================================================

app.get('/upload-image', async (req, res) => {
  res.render('upload-image');
});

app.post('/upload-image', upload.single('image'), async (req, res) => {
  try {
    const image = await client.images.create({
      content_type: req.file.mimetype,
      file: req.file.path
    });

    fs.unlink(req.file.path)

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
    res.render('not-found');
  }
});

app.post('/images/:id/delete', async (req, res) => {
  try {
    await client.images.delete(req.params.id);

    res.redirect('/')
  } catch (error) {
    res.render('not-found');
  }
});

// HOME
// =============================================================================

app.get('/', async (req, res) => {
  res.render('index');
});

app.listen(3000);
