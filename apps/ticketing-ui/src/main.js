const state = {
  films: [],
  selectedFilm: null,
  selectedSchedule: null,
  layout: null,
  selectedSeats: [],
  step: 'browse', // browse | pay | processing | done
  wallet: null,
  paymentMethod: null,
  result: null,
  error: null,
};

const cinemaBase = import.meta.env.VITE_CINEMA_URL || '';
const layoutBase = import.meta.env.VITE_LAYOUT_URL || '';
const checkoutBase = import.meta.env.VITE_CHECKOUT_URL || '';
const paymentBase = import.meta.env.VITE_PAYMENT_URL || '';

async function api(base, path, opts) {
  const res = await fetch(`${base}${path}`, opts);
  const text = await res.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!res.ok) throw new Error(typeof data === 'object' && data?.error ? data.error : text || res.statusText);
  return data;
}

async function loadFilms() {
  state.films = await api(cinemaBase, '/api/films');
  render();
}

async function selectSchedule(film, schedule) {
  state.selectedFilm = film;
  state.selectedSchedule = schedule;
  state.selectedSeats = [];
  state.result = null;
  state.error = null;
  state.step = 'browse';
  state.wallet = null;
  state.paymentMethod = null;
  state.layout = await api(layoutBase, `/api/layouts/${schedule.id}`);
  render();
}

function toggleSeat(seat) {
  if (seat.status === 'taken') return;
  const i = state.selectedSeats.indexOf(seat.id);
  if (i >= 0) state.selectedSeats.splice(i, 1);
  else state.selectedSeats.push(seat.id);
  render();
}

async function goToPayment() {
  state.error = null;
  state.result = null;
  try {
    state.wallet = await api(paymentBase, '/api/wallet?customer=lab-student');
    state.step = 'pay';
    state.paymentMethod = null;
  } catch (e) {
    state.error = e.message;
    state.step = 'browse';
  }
  render();
}

function selectMethod(id) {
  state.paymentMethod = id;
  state.error = null;
  render();
}

async function confirmPay() {
  if (!state.paymentMethod) return;
  state.error = null;
  state.result = null;
  state.step = 'processing';
  render();

  try {
    const amount = state.selectedSchedule.price * state.selectedSeats.length;
    state.result = await api(checkoutBase, '/api/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        film_id: state.selectedFilm.id,
        schedule_id: state.selectedSchedule.id,
        seats: state.selectedSeats,
        amount,
        customer: 'lab-student',
        payment_method: state.paymentMethod,
      }),
    });
    state.step = 'done';
  } catch (e) {
    state.error = e.message;
    state.step = 'pay';
  }
  render();
}

function render() {
  const app = document.getElementById('app');
  const amount = state.selectedSchedule
    ? state.selectedSchedule.price * state.selectedSeats.length
    : 0;

  const gopay = state.wallet?.methods?.find((m) => m.id === 'gopay');
  const qris = state.wallet?.methods?.find((m) => m.id === 'qris');

  app.innerHTML = `
    <header>
      <div>
        <p class="eyebrow">APM Lab · New Relic Go Agent</p>
        <h1>mLab Ticketing</h1>
        <p class="muted">Happy flow: film → kursi → metode bayar → proses → sukses</p>
      </div>
      <button class="secondary" id="reload">Muat Ulang Film</button>
    </header>

    <section class="card">
      <h2>1) Pilih Film & Jadwal</h2>
      ${state.films.map((f) => `
        <div class="film">
          <div>
            <strong>${f.title}</strong>
            <div class="muted">${f.genre} · ${f.duration_min} menit</div>
            ${(f.cinemas || []).map((c) => `
              <div class="muted" style="margin-top:0.5rem">${c.name} (${c.city})</div>
              <div style="display:flex;flex-wrap:wrap;gap:0.4rem;margin-top:0.35rem">
                ${(c.schedules || []).map((s) => `
                  <button data-film="${f.id}" data-sch="${s.id}">${s.time} · ${s.hall} · Rp ${s.price.toLocaleString('id-ID')}</button>
                `).join('')}
              </div>
            `).join('')}
          </div>
        </div>
      `).join('') || '<p class="muted">Memuat film…</p>'}
    </section>

    ${state.layout && state.step !== 'processing' ? `
      <section class="card">
        <h2>2) Pilih Kursi — ${state.selectedFilm.title} @ ${state.selectedSchedule.time}</h2>
        <div class="seats">
          ${state.layout.seats.map((seat) => `
            <button class="seat ${seat.status} ${state.selectedSeats.includes(seat.id) ? 'selected' : ''}"
              data-seat="${seat.id}" ${seat.status === 'taken' || state.step === 'done' ? 'disabled' : ''}>${seat.id}</button>
          `).join('')}
        </div>
        <p class="muted" style="margin-top:0.75rem">Dipilih: ${state.selectedSeats.join(', ') || '—'} · Total Rp ${amount.toLocaleString('id-ID')}</p>
        ${state.step === 'browse' ? `
          <button id="to-pay" ${state.selectedSeats.length ? '' : 'disabled'}>3) Lanjut ke Pembayaran</button>
        ` : ''}
      </section>
    ` : ''}

    ${state.step === 'pay' ? `
      <section class="card">
        <h2>3) Pilih Metode Pembayaran</h2>
        <p class="muted">Total tagihan: <strong style="color:#e2e8f0">Rp ${amount.toLocaleString('id-ID')}</strong></p>
        <div class="methods">
          <button type="button" class="method ${state.paymentMethod === 'gopay' ? 'active' : ''}" data-method="gopay">
            <span class="method-name">GoPay</span>
            <span class="method-desc">${gopay?.description || 'E-wallet'}</span>
            <span class="method-balance">Saldo: Rp ${(gopay?.balance ?? 0).toLocaleString('id-ID')}</span>
          </button>
          <button type="button" class="method ${state.paymentMethod === 'qris' ? 'active' : ''}" data-method="qris">
            <span class="method-name">QRIS</span>
            <span class="method-desc">${qris?.description || 'Scan QR'}</span>
            <span class="method-balance">Konfirmasi otomatis setelah proses</span>
          </button>
        </div>
        ${state.paymentMethod === 'qris' ? `
          <div class="qris-box">
            <div class="qris-fake" aria-hidden="true"></div>
            <p class="muted">Scan QR (simulasi). Setelah klik bayar, sistem menunggu konfirmasi partner.</p>
          </div>
        ` : ''}
        <div style="display:flex;gap:0.5rem;margin-top:1rem;flex-wrap:wrap">
          <button id="confirm-pay" ${state.paymentMethod ? '' : 'disabled'}>Bayar Sekarang</button>
          <button class="secondary" id="back-seats">Kembali</button>
        </div>
      </section>
    ` : ''}

    ${state.step === 'processing' ? `
      <section class="card processing">
        <div class="spinner" aria-hidden="true"></div>
        <h2>Pembayaran sedang diproses…</h2>
        <p class="muted">Metode: ${state.paymentMethod === 'gopay' ? 'GoPay' : 'QRIS'} · menunggu konfirmasi partner (bank gateway).</p>
      </section>
    ` : ''}

    ${state.step === 'done' && state.result ? `
      <section class="card">
        <h2 class="ok">Pembayaran berhasil</h2>
        <p class="muted">Metode: ${state.result.payment_method || state.paymentMethod}</p>
        <pre>${JSON.stringify(state.result, null, 2)}</pre>
      </section>
    ` : ''}

    ${state.error ? `
      <section class="card">
        <h2 class="err">Gagal</h2>
        <p>${state.error}</p>
      </section>
    ` : ''}
  `;

  document.getElementById('reload')?.addEventListener('click', () => {
    state.step = 'browse';
    state.error = null;
    loadFilms();
  });
  document.querySelectorAll('button[data-film]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const film = state.films.find((f) => f.id === btn.dataset.film);
      const schedule = film.cinemas.flatMap((c) => c.schedules).find((s) => s.id === btn.dataset.sch);
      selectSchedule(film, schedule);
    });
  });
  document.querySelectorAll('button[data-seat]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const seat = state.layout.seats.find((s) => s.id === btn.dataset.seat);
      toggleSeat(seat);
    });
  });
  document.getElementById('to-pay')?.addEventListener('click', goToPayment);
  document.querySelectorAll('button[data-method]').forEach((btn) => {
    btn.addEventListener('click', () => selectMethod(btn.dataset.method));
  });
  document.getElementById('confirm-pay')?.addEventListener('click', confirmPay);
  document.getElementById('back-seats')?.addEventListener('click', () => {
    state.step = 'browse';
    state.error = null;
    render();
  });
}

loadFilms().catch((e) => {
  state.error = e.message;
  render();
});
