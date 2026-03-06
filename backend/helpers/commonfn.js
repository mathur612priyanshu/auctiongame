const generateRandom4DigitNumber = () => {
  return Math.floor(1000 + Math.random() * 9000);
};

const generateRandom6DigitNumber = () => {
  return Math.floor(100000 + Math.random() * 900000);
};
module.exports = { generateRandom4DigitNumber, generateRandom6DigitNumber };
