const scoreboard = document.getElementById('scoreboard');
const themes = {
    modern: 'theme-modern',
    arena: 'theme-arena',
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
    row.querySelector('.color').style.backgroundColor = '#' + team.rgb.toString(16).padStart(6, '0');
    row.querySelector('.serve').classList.toggle('serving', serving === side);
}

window.addEventListener('overlay:update', event => {
    const match = event.detail;
    document.body.className = themes[match.theme] ?? themes.modern;
    renderTeam('home', match.home, match.serving);
    renderTeam('away', match.away, match.serving);
    scoreboard.hidden = false;
});
