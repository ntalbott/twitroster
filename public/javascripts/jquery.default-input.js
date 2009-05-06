(function($){  
  $.fn.defaultInput = function(options) {  
  
    this.each(function() {  
      var $this = $(this);  
      var title = $this.attr('title');
            
      $this.focus(function() {
             if($this.val() == title || $this.val() == '') $this.val('').removeClass('default');
           })
           .blur(function() {
             if($this.val() == title || $this.val() == '') $this.val(title).addClass('default');
           })
           .trigger('blur');
           
      $this.parents('form').submit(function() {
        $this.trigger('focus');
      });
      
      
    });
    
    return this;  
  }  
})(jQuery);