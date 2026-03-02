(() => {
  const lsKey = 'tea_admin_api_base';
  const fmtMoney = v => Number(v || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const fmtTime = s => {
    if (!s) return '';
    const d = new Date(s);
    if (Number.isNaN(d.getTime())) return s;
    return d.toLocaleString();
  };
  const statusClass = s => (s === 'paid' ? 'paid' : s === 'partially_refunded' ? 'partial' : 'refunded');
  const statusText = s => (s === 'paid' ? 'Paid' : s === 'partially_refunded' ? 'Partially Refunded' : 'Refunded');

  const getApiBase = () => {
    const raw = (localStorage.getItem(lsKey) || '').trim();
    return raw || `${location.protocol}//${location.hostname}:8080`;
  };

  const api = path => `${getApiBase()}${path}`;

  async function loadHealth() {
    const el = document.getElementById('health');
    try {
      const r = await fetch(api('/healthz'));
      const j = await r.json();
      el.textContent = `Backend: ${j.status || 'unknown'}`;
      el.style.color = j.status === 'ok' ? '#2e7d32' : '#c62828';
    } catch {
      el.textContent = 'Backend: error';
      el.style.color = '#c62828';
    }
  }

  async function loadOrders() {
    const tbody = document.getElementById('tbody');
    const q = (document.getElementById('q').value || '').trim().toLowerCase();
    const sf = document.getElementById('status').value;
    tbody.innerHTML = '<tr><td colspan="6" class="muted">Loading...</td></tr>';
    try {
      const r = await fetch(api('/api/v1/orders'));
      const j = await r.json();
      const items = (j.items || [])
        .filter(o => {
          const okQ = !q || (o.order_no || '').toLowerCase().includes(q) || (o.channel || '').toLowerCase().includes(q);
          const okS = !sf || o.status === sf;
          return okQ && okS;
        })
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
      document.getElementById('count').textContent = `Orders: ${items.length}`;
      if (!items.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="muted">No data</td></tr>';
        return;
      }
      tbody.innerHTML = items
        .map(
          o =>
            '<tr>' +
            `<td>${o.order_no || ''}</td>` +
            `<td>${o.order_type || ''}</td>` +
            `<td>${o.channel || ''}</td>` +
            `<td>${fmtMoney(o.total)}</td>` +
            `<td><span class="badge ${statusClass(o.status)}">${statusText(o.status)}</span></td>` +
            `<td>${fmtTime(o.created_at)}</td>` +
            '</tr>'
        )
        .join('');
    } catch (e) {
      tbody.innerHTML = `<tr><td colspan="6" style="color:#c62828">Load failed: ${String(e)}</td></tr>`;
    }
  }

  async function loadStats() {
    const date = document.getElementById('statDate').value;
    if (!date) return;
    try {
      const r = await fetch(api(`/api/v1/stats/daily?date=${encodeURIComponent(date)}`));
      const j = await r.json();
      document.getElementById('kOrder').textContent = j.order_count ?? '-';
      document.getElementById('kGross').textContent = fmtMoney(j.gross_amount);
      document.getElementById('kRefund').textContent = fmtMoney(j.refunds);
      document.getElementById('kNet').textContent = fmtMoney(j.net_amount);
    } catch {
      document.getElementById('kOrder').textContent = 'ERR';
      document.getElementById('kGross').textContent = 'ERR';
      document.getElementById('kRefund').textContent = 'ERR';
      document.getElementById('kNet').textContent = 'ERR';
    }
  }

  document.getElementById('apiBase').value = getApiBase();
  document.getElementById('saveApi').addEventListener('click', () => {
    const value = (document.getElementById('apiBase').value || '').trim();
    if (!value) return;
    localStorage.setItem(lsKey, value.replace(/\/$/, ''));
    loadHealth();
    loadOrders();
    loadStats();
  });
  document.getElementById('refresh').addEventListener('click', loadOrders);
  document.getElementById('q').addEventListener('input', loadOrders);
  document.getElementById('status').addEventListener('change', loadOrders);
  document.getElementById('loadStat').addEventListener('click', loadStats);

  const d = new Date();
  document.getElementById('statDate').value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

  loadHealth();
  loadOrders();
  loadStats();
})();
