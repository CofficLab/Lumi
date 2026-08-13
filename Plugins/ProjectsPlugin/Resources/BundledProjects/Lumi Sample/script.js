const button = document.querySelector('#spark-button');
const message = document.querySelector('#message');

const sparks = [
  'Nice. Now make it unmistakably yours.',
  'A small change is how every project starts.',
  'Ready for the next idea.'
];

button.addEventListener('click', () => {
  message.textContent = sparks[Math.floor(Math.random() * sparks.length)];
});
