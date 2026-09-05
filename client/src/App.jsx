import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Link, useNavigate } from 'react-router-dom';

const API = 'http://localhost:4000/api';

function Nav() {
  return (
    <div className="nav">
      <Link to="/login">Iniciar sesión</Link>
      <Link to="/register">Registrarse</Link>
    </div>
  );
}

// HU-02 · Login seguro
function Login({ setUsuario }) {
  const [correo, setCorreo] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  async function onSubmit(e) {
    e.preventDefault();
    setError('');
    const res = await fetch(`${API}/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ correo, password }),
    });
    const data = await res.json();
    if (!res.ok) {
      setError(data.error);
      return;
    }
    setUsuario(data);
    navigate('/dashboard');
  }

  return (
    <>
      <Nav />
      <h1>Iniciar sesión</h1>
      <form onSubmit={onSubmit}>
        <label>Correo</label>
        <input type="email" value={correo} onChange={(e) => setCorreo(e.target.value)} required />
        <label>Contraseña</label>
        <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        {error && <p className="error">{error}</p>}
        <button type="submit">Entrar</button>
      </form>
    </>
  );
}

// HU-01 · Registro de residente
function Register() {
  const [viviendas, setViviendas] = useState([]);
  const [form, setForm] = useState({ id_vivienda: '', nombre_completo: '', correo: '', password: '', telefono: '' });
  const [error, setError] = useState('');
  const [ok, setOk] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    fetch(`${API}/viviendas`).then((r) => r.json()).then(setViviendas);
  }, []);

  function update(field) {
    return (e) => setForm({ ...form, [field]: e.target.value });
  }

  async function onSubmit(e) {
    e.preventDefault();
    setError('');
    const res = await fetch(`${API}/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form),
    });
    const data = await res.json();
    if (!res.ok) {
      setError(data.error);
      return;
    }
    setOk(true);
    setTimeout(() => navigate('/login'), 1200);
  }

  return (
    <>
      <Nav />
      <h1>Registro de residente</h1>
      <form onSubmit={onSubmit}>
        <label>Vivienda</label>
        <select value={form.id_vivienda} onChange={update('id_vivienda')} required>
          <option value="">Selecciona tu vivienda</option>
          {viviendas.map((v) => (
            <option key={v.id_vivienda} value={v.id_vivienda}>
              {v.numero_vivienda} — {v.propietario_nombre}
            </option>
          ))}
        </select>
        <label>Nombre completo</label>
        <input value={form.nombre_completo} onChange={update('nombre_completo')} required />
        <label>Correo</label>
        <input type="email" value={form.correo} onChange={update('correo')} required />
        <label>Teléfono</label>
        <input value={form.telefono} onChange={update('telefono')} />
        <label>Contraseña</label>
        <input type="password" value={form.password} onChange={update('password')} required minLength={6} />
        {error && <p className="error">{error}</p>}
        {ok && <p>Registro exitoso, redirigiendo a inicio de sesión…</p>}
        <button type="submit">Registrarme</button>
      </form>
    </>
  );
}

// HU-05 · confirma visualmente que el entorno (API + base de datos) está funcionando
function Dashboard({ usuario }) {
  if (!usuario) {
    return (
      <>
        <Nav />
        <p>No has iniciado sesión.</p>
      </>
    );
  }
  return (
    <>
      <h1>Bienvenido, {usuario.nombre_completo}</h1>
      <div className="card">
        <p><b>Correo:</b> {usuario.correo}</p>
        <p><b>Rol:</b> {usuario.rol}</p>
        <p><b>Vivienda:</b> {usuario.vivienda || 'N/A'}</p>
      </div>
    </>
  );
}

export default function App() {
  const [usuario, setUsuario] = useState(null);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Login setUsuario={setUsuario} />} />
        <Route path="/login" element={<Login setUsuario={setUsuario} />} />
        <Route path="/register" element={<Register />} />
        <Route path="/dashboard" element={<Dashboard usuario={usuario} />} />
      </Routes>
    </BrowserRouter>
  );
}
