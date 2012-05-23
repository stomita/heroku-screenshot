var socket;
function init() {
  socket = io.connect("/request");
  $('form').submit(function(e) {
    e.preventDefault();
    e.stopPropagation();
    var url = $('#url').val();
    socket.emit("render", url);
    return false;
  });
  socket.on("image", function(imageUrl) {
    $('<img>').attr('src', imageUrl).prependTo($('#images'));
    if ($('img').size() > 10) {
      $('img:last-child').remove();
    }
  });
}

$(init);

