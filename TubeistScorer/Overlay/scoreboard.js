const scoreboard = document.getElementById('scoreboard');
const racketScoreboard = document.getElementById('racket-scoreboard');
const baseballScoreboard = document.getElementById('baseball-scoreboard');
const cricketScoreboard = document.getElementById('cricket-scoreboard');
const timedScoreboard = document.getElementById('timed-scoreboard');
const periodLabel = document.getElementById('timed-period-label');
const clock = document.getElementById('timed-clock');
const situation = document.getElementById('timed-situation');
let clockTimer;
const themes = {
    modern: 'theme-modern horizontal-scoreboard',
    arena: 'theme-arena horizontal-scoreboard',
    courtside: 'theme-arena theme-courtside',
    retro: 'theme-retro',
    daylight: 'theme-daylight',
    legacy: 'theme-legacy'
};

function renderTeam(side, team, serving) {
    const row = scoreboard.querySelector('.' + side);
    row.querySelector('.team').textContent = team.name;
    row.querySelector('.score').textContent = team.points;
    row.querySelector('.set').textContent = team.sets;
    row.querySelector('.color').style.backgroundColor = jerseyColor(team);
    row.querySelector('.serve').classList.toggle('serving', serving === side);
}

function jerseyColor(team) {
    return '#' + team.rgb.toString(16).padStart(6, '0');
}

function renderCompactTeam(id, team, active, score = team.points) {
    const row = document.getElementById(id);
    row.querySelector('.team-name').textContent = team.name;
    row.querySelector('.team-points').textContent = score;
    row.querySelector('.possession-marker').classList.toggle('has-ball', active);
    row.querySelector('.jersey-color').style.backgroundColor = jerseyColor(team);
}

function renderBaseball(match, game) {
    renderCompactTeam('baseball-away', match.away, game.batting === 'away');
    renderCompactTeam('baseball-home', match.home, game.batting === 'home');
    document.getElementById('baseball-inning').textContent = game.inning;
    const outLabel = game.outs === 1 ? ' out' : ' outs';
    document.getElementById('baseball-count').textContent = game.balls + '–' + game.strikes + ' · ' + game.outs + outLabel;
    for (const base of baseballScoreboard.querySelectorAll('[data-base]')) {
        base.classList.toggle('occupied', game.bases.includes(Number(base.dataset.base)));
    }
}

function renderCricket(match, cricket) {
    renderCompactTeam('cricket-home', match.home, cricket.batting === 'home', cricket.homeScore);
    renderCompactTeam('cricket-away', match.away, cricket.batting === 'away', cricket.awayScore);
    document.getElementById('cricket-status').textContent = cricket.status;
    document.getElementById('cricket-overs').textContent = cricket.overs + ' ov';
    const target = document.getElementById('cricket-target');
    target.hidden = cricket.target === undefined;
    target.textContent = target.hidden ? '' : 'Target ' + cricket.target;
}

function renderRacketSide(side, team, score) {
    const row = document.getElementById('racket-' + side);
    row.querySelector('.racket-name').textContent = team.name;
    row.querySelector('.racket-points').textContent = score.points;
    row.querySelector('.racket-games').textContent = score.games ?? '';
    row.querySelector('.racket-sets').textContent = score.sets ?? '';
    row.querySelector('.jersey-color').style.backgroundColor = jerseyColor(team);
    const serve = row.querySelector('.racket-serve');
    serve.classList.toggle('is-serving', score.serving);
    serve.textContent = score.serverNumber ?? '';
}

function renderClock(timing, statusAtZero) {
    const startedAt = Number.isFinite(timing.startedAt) ? timing.startedAt : null;
    const elapsed = startedAt === null ? 0 : Math.max(0, Date.now() / 1000 - startedAt);
    const time = Math.min(timing.maximumSeconds, Math.max(0, timing.seconds + (timing.countsDown ? -elapsed : elapsed)));
    const tenths = Math.ceil(time * 10);
    const seconds = timing.countsDown ? Math.ceil(tenths / 10) : Math.floor(time);
    const label = (timing.showsTenths ?? timing.countsDown) && tenths < 600
        ? Math.floor(tenths / 10) + '.' + tenths % 10
        : Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0');
    if (clock.textContent !== label) clock.textContent = label;
    if (time === 0 && statusAtZero && periodLabel.textContent !== statusAtZero) {
        periodLabel.textContent = statusAtZero;
    }
    return startedAt !== null && (timing.countsDown ? time > 0 : time < timing.maximumSeconds);
}

function updateClock(game) {
    clock.hidden = !game.clock;
    if (game.clock && renderClock(game.clock, game.statusAtZero)) {
        clockTimer = setInterval(() => {
            if (!renderClock(game.clock, game.statusAtZero)) clearInterval(clockTimer);
        }, 100);
    }
}

window.addEventListener('overlay:update', event => {
    const match = event.detail;
    const {game, racket, baseball, cricket} = match;
    const scale = Number.isFinite(match.overlayScale) ? Math.max(0.25, Math.min(2, match.overlayScale)) : 1;
    document.body.className = themes[match.theme] ?? themes.modern;
    scoreboard.hidden = Boolean(game || racket || baseball || cricket);
    timedScoreboard.hidden = !game;
    racketScoreboard.hidden = !racket;
    baseballScoreboard.hidden = !baseball;
    cricketScoreboard.hidden = !cricket;
    clearInterval(clockTimer);

    if (game) {
        timedScoreboard.style.setProperty('--overlay-scale', scale === 1 ? 'none' : String(scale));
        timedScoreboard.classList.toggle('shows-possession', Boolean(game.possession));
        renderCompactTeam('timed-home', match.home, game.possession === 'home');
        renderCompactTeam('timed-away', match.away, game.possession === 'away');
        situation.hidden = !game.situation;
        situation.textContent = game.situation ?? '';
        periodLabel.textContent = game.period;
        updateClock(game);
    } else if (baseball) {
        baseballScoreboard.style.setProperty('--overlay-scale', scale === 1 ? 'none' : String(scale));
        renderBaseball(match, baseball);
    } else if (cricket) {
        cricketScoreboard.style.setProperty('--overlay-scale', scale === 1 ? 'none' : String(scale));
        renderCricket(match, cricket);
    } else if (racket) {
        racketScoreboard.style.setProperty('--overlay-scale', scale === 1 ? 'none' : String(scale));
        racketScoreboard.classList.toggle('games-only', racket.home.sets === undefined);
        racketScoreboard.classList.toggle('sets-only', racket.home.games === undefined);
        document.getElementById('racket-status').textContent = racket.status ?? '';
        renderRacketSide('home', match.home, racket.home);
        renderRacketSide('away', match.away, racket.away);
    } else {
        scoreboard.style.setProperty('--overlay-scale', scale === 1 ? 'none' : String(scale));
        renderTeam('home', match.home, match.serving);
        renderTeam('away', match.away, match.serving);
    }
});
