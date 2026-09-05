const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const app = express();
app.use(cors());
app.use(express.json());

const ROL_RESIDENTE = 3;

// HU-01 · datos de apoyo para el formulario de registro (viviendas activas del padrón)
app.get('/api/viviendas', async (_req, res) => {
  const viviendas = await prisma.viviendas.findMany({
    where: { estado: 'activa' },
    select: { id_vivienda: true, numero_vivienda: true, propietario_nombre: true },
  });
  res.json(viviendas);
});

// HU-01 · Registro de residente
app.post('/api/register', async (req, res) => {
  const { id_vivienda, nombre_completo, correo, password, telefono } = req.body;

  if (!id_vivienda || !nombre_completo || !correo || !password) {
    return res.status(400).json({ error: 'Faltan campos obligatorios.' });
  }

  const existente = await prisma.usuarios.findUnique({ where: { correo } });
  if (existente) {
    return res.status(409).json({ error: 'Ese correo ya está registrado.' });
  }

  const password_hash = await bcrypt.hash(password, 10);

  const usuario = await prisma.usuarios.create({
    data: {
      id_vivienda: Number(id_vivienda),
      id_rol: ROL_RESIDENTE,
      nombre_completo,
      correo,
      password_hash,
      telefono: telefono || null,
    },
  });

  res.status(201).json({ id_usuario: usuario.id_usuario, nombre_completo, correo });
});

// HU-02 · Login seguro
app.post('/api/login', async (req, res) => {
  const { correo, password } = req.body;
  if (!correo || !password) {
    return res.status(400).json({ error: 'Correo y contraseña son obligatorios.' });
  }

  const usuario = await prisma.usuarios.findUnique({
    where: { correo },
    include: { roles: true, viviendas: true },
  });

  if (!usuario || !usuario.activo) {
    return res.status(401).json({ error: 'Credenciales inválidas.' });
  }

  const passwordOk = await bcrypt.compare(password, usuario.password_hash);
  if (!passwordOk) {
    return res.status(401).json({ error: 'Credenciales inválidas.' });
  }

  res.json({
    id_usuario: usuario.id_usuario,
    nombre_completo: usuario.nombre_completo,
    correo: usuario.correo,
    rol: usuario.roles.nombre,
    vivienda: usuario.viviendas ? usuario.viviendas.numero_vivienda : null,
  });
});

const PORT = 4000;
app.listen(PORT, () => console.log(`API escuchando en http://localhost:${PORT}`));
